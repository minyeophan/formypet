package com.formypet.domain.media;

import com.formypet.domain.media.service.MediaStorageAttempts;
import com.formypet.domain.media.scheduling.MediaCleanupRunner;

import com.formypet.domain.media.storage.MediaStorage;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import com.formypet.domain.media.repository.jdbc.MediaWorkRepository;

import java.io.IOException;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class MediaCleanupRunnerTest {


    @Mock MediaWorkRepository work;
    @Mock MediaStorage mediaStorage;
    @Mock MediaStorageAttempts storageAttempts;

    private MediaCleanupRunner runner;

    @BeforeEach
    void setUp() {
        runner = new MediaCleanupRunner(work, mediaStorage, storageAttempts);
    }

    @Test
    void emptyQueueDoesNothing() {
        when(work.pendingKeys()).thenReturn(List.of());

        assertDoesNotThrow(() -> runner.run(null));

        verifyNoInteractions(mediaStorage);
        verify(work, never()).deleteQueued(anyString());
    }

    @Test
    void referencedFileIsNeverDeletedEvenIfItWasQueued() throws Exception {
        when(work.pendingKeys()).thenReturn(List.of("live/photo.png"));
        when(work.referenceCount("live/photo.png")).thenReturn(1);
        runner.run(null);
        verifyNoInteractions(mediaStorage);
        verify(work, never()).deleteQueued( "live/photo.png");
    }

    @Test
    void successfulFileDeletionRemovesQueueRow() throws Exception {
        when(work.pendingKeys()).thenReturn(List.of("records/old.jpg"));

        runner.run(null);

        verify(mediaStorage).delete("records/old.jpg");
        verify(work).deleteQueued( "records/old.jpg");
    }

    @Test
    void fileDeletionFailurePreservesRowAndContinues() throws Exception {
        when(work.pendingKeys())
                .thenReturn(List.of("records/fail.jpg", "records/next.jpg"));
        doThrow(new IOException("disk failure")).when(mediaStorage).delete("records/fail.jpg");

        runner.run(null);

        verify(work, never()).deleteQueued( "records/fail.jpg");
        verify(mediaStorage).delete("records/next.jpg");
        verify(work).deleteQueued( "records/next.jpg");
    }

    @Test
    void queueDeletionFailurePreservesRowAndContinues() throws Exception {
        when(work.pendingKeys())
                .thenReturn(List.of("records/fail.jpg", "records/next.jpg"));
        doThrow(new IllegalStateException("database failure"))
                .when(work).deleteQueued( "records/fail.jpg");

        runner.run(null);

        verify(mediaStorage).delete("records/fail.jpg");
        verify(mediaStorage).delete("records/next.jpg");
        verify(work).deleteQueued( "records/next.jpg");
    }

    @Test
    void queueReadFailureDoesNotBlockStartup() {
        when(work.pendingKeys())
                .thenThrow(new IllegalStateException("database unavailable"));

        assertDoesNotThrow(() -> runner.run(null));

        verifyNoInteractions(mediaStorage);
    }
}
