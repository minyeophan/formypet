package com.petyilgi.media;

import com.petyilgi.media.storage.MediaStorage;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.jdbc.core.JdbcTemplate;

import java.io.IOException;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class MediaCleanupRunnerTest {

    private static final String DELETE_SQL = "DELETE FROM media_cleanup_queue WHERE storage_key = ?";

    @Mock JdbcTemplate jdbcTemplate;
    @Mock MediaStorage mediaStorage;

    private MediaCleanupRunner runner;

    @BeforeEach
    void setUp() {
        runner = new MediaCleanupRunner(jdbcTemplate, mediaStorage);
    }

    @Test
    void emptyQueueDoesNothing() {
        when(jdbcTemplate.queryForList(anyString(), eq(String.class))).thenReturn(List.of());

        assertDoesNotThrow(() -> runner.run(null));

        verifyNoInteractions(mediaStorage);
        verify(jdbcTemplate, never()).update(anyString(), anyString());
    }

    @Test
    void successfulFileDeletionRemovesQueueRow() throws Exception {
        when(jdbcTemplate.queryForList(anyString(), eq(String.class))).thenReturn(List.of("records/old.jpg"));

        runner.run(null);

        verify(mediaStorage).delete("records/old.jpg");
        verify(jdbcTemplate).update(DELETE_SQL, "records/old.jpg");
    }

    @Test
    void fileDeletionFailurePreservesRowAndContinues() throws Exception {
        when(jdbcTemplate.queryForList(anyString(), eq(String.class)))
                .thenReturn(List.of("records/fail.jpg", "records/next.jpg"));
        doThrow(new IOException("disk failure")).when(mediaStorage).delete("records/fail.jpg");

        runner.run(null);

        verify(jdbcTemplate, never()).update(DELETE_SQL, "records/fail.jpg");
        verify(mediaStorage).delete("records/next.jpg");
        verify(jdbcTemplate).update(DELETE_SQL, "records/next.jpg");
    }

    @Test
    void queueDeletionFailurePreservesRowAndContinues() throws Exception {
        when(jdbcTemplate.queryForList(anyString(), eq(String.class)))
                .thenReturn(List.of("records/fail.jpg", "records/next.jpg"));
        doThrow(new IllegalStateException("database failure"))
                .when(jdbcTemplate).update(DELETE_SQL, "records/fail.jpg");

        runner.run(null);

        verify(mediaStorage).delete("records/fail.jpg");
        verify(mediaStorage).delete("records/next.jpg");
        verify(jdbcTemplate).update(DELETE_SQL, "records/next.jpg");
    }

    @Test
    void queueReadFailureDoesNotBlockStartup() {
        when(jdbcTemplate.queryForList(anyString(), eq(String.class)))
                .thenThrow(new IllegalStateException("database unavailable"));

        assertDoesNotThrow(() -> runner.run(null));

        verifyNoInteractions(mediaStorage);
    }
}
