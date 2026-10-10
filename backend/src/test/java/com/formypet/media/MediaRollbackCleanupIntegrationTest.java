package com.formypet.media;

import com.formypet.media.storage.MediaStorage;
import com.formypet.media.storage.StoredMedia;
import com.formypet.support.IntegrationTestSupport;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.transaction.support.TransactionTemplate;
import java.io.IOException;
import java.util.UUID;
import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@TestPropertySource(properties="app.media.cleanup-interval-ms=3600000")
class MediaRollbackCleanupIntegrationTest extends IntegrationTestSupport {
    @Autowired MediaService media;
    @Autowired JdbcTemplate jdbc;
    @Autowired TransactionTemplate transactions;
    @MockitoBean MediaStorage storage;
    @org.springframework.test.context.bean.override.mockito.MockitoSpyBean OrphanMediaCleanup cleanup;
    @Autowired MediaStorageAttempts attempts;

    @Test void lostStorageResponseAndFailedCleanupQueueRemainRecoverable() throws Exception {
        String email=UUID.randomUUID()+"@lost-response.test";
        jdbc.update("INSERT INTO users(email,password_hash,nickname) VALUES (?,'unused','lostresponse')",email);
        long userId=jdbc.queryForObject("SELECT id FROM users WHERE email=?",Long.class,email);
        var savedKey = new java.util.concurrent.atomic.AtomicReference<String>();
        when(storage.storeAt(anyString(),any())).thenAnswer(call -> {
            savedKey.set(call.getArgument(0));
            throw new IOException("write accepted but response lost");
        });
        doThrow(new IOException("delete unavailable")).when(storage).delete(anyString());
        doThrow(new IllegalStateException("queue unavailable")).when(cleanup).enqueue(anyString());
        org.assertj.core.api.Assertions.assertThatThrownBy(() ->
                media.uploadUserProfileMedia(userId,new MockMultipartFile("file","photo.png","image/png",new byte[]{1})))
                .isInstanceOf(IllegalStateException.class).hasMessage("Failed to store media file.");
        String key=savedKey.get();
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM media_storage_attempts WHERE storage_key=?",Integer.class,key)).isEqualTo(1);
        assertThat(jdbc.queryForObject("SELECT media_bytes_used FROM users WHERE id=?",Long.class,userId)).isZero();
        jdbc.update("UPDATE media_storage_attempts SET created_at=UTC_TIMESTAMP(6)-INTERVAL 2 HOUR WHERE storage_key=?",key);
        attempts.recover();
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM media_cleanup_queue WHERE storage_key=?",Integer.class,key)).isEqualTo(1);
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM media_storage_attempts WHERE storage_key=?",Integer.class,key)).isZero();
    }

    @Test void failedRollbackFileRemovalPersistsRetryOutsideTheRolledBackTransaction() throws Exception {
        String email=UUID.randomUUID()+"@rollback.test";
        jdbc.update("INSERT INTO users(email,password_hash,nickname) VALUES (?,'unused','rollback')",email);
        long userId=jdbc.queryForObject("SELECT id FROM users WHERE email=?",Long.class,email);
        var savedKey = new java.util.concurrent.atomic.AtomicReference<String>();
        when(storage.storeAt(anyString(),any())).thenAnswer(call -> {
            String key = call.getArgument(0);
            savedKey.set(key);
            return new StoredMedia(key,"image/webp",1);
        });
        doThrow(new IOException("simulated unavailable storage")).when(storage).delete(anyString());
        transactions.executeWithoutResult(status -> {
            media.uploadUserProfileMedia(userId,new MockMultipartFile("file","photo.webp","image/webp",new byte[]{1}));
            status.setRollbackOnly();
        });
        String key = savedKey.get();
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM media_resources WHERE storage_key=?",Integer.class,key)).isZero();
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM media_cleanup_queue WHERE storage_key=?",Integer.class,key)).isEqualTo(1);
        verify(storage).delete(key);
    }
}
