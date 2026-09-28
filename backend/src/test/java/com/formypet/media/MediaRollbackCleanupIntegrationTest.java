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

    @Test void failedRollbackFileRemovalPersistsRetryOutsideTheRolledBackTransaction() throws Exception {
        String email=UUID.randomUUID()+"@rollback.test";
        jdbc.update("INSERT INTO users(email,password_hash,nickname) VALUES (?,'unused','rollback')",email);
        long userId=jdbc.queryForObject("SELECT id FROM users WHERE email=?",Long.class,email);
        String key=userId+"/profile/"+UUID.randomUUID()+".webp";
        when(storage.store(eq(userId),eq("profile"),eq("webp"),any()))
                .thenReturn(new StoredMedia(key,"image/webp",1));
        doThrow(new IOException("simulated unavailable storage")).when(storage).delete(key);
        transactions.executeWithoutResult(status -> {
            media.uploadUserProfileMedia(userId,new MockMultipartFile("file","photo.webp","image/webp",new byte[]{1}));
            status.setRollbackOnly();
        });
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM media_resources WHERE storage_key=?",Integer.class,key)).isZero();
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM media_cleanup_queue WHERE storage_key=?",Integer.class,key)).isEqualTo(1);
        verify(storage).delete(key);
    }
}
