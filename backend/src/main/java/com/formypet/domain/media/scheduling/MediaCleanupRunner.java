package com.formypet.domain.media.scheduling;

import com.formypet.domain.media.service.MediaStorageAttempts;

import com.formypet.domain.media.storage.MediaStorage;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import com.formypet.domain.media.repository.jdbc.MediaWorkRepository;
import org.springframework.stereotype.Component;
import org.springframework.scheduling.annotation.Scheduled;

import java.util.List;
import java.util.concurrent.atomic.AtomicBoolean;

@Slf4j
@Component
@RequiredArgsConstructor
public class MediaCleanupRunner implements ApplicationRunner {

    private final MediaWorkRepository work;
    private final MediaStorage mediaStorage;
    private final MediaStorageAttempts storageAttempts;
    private final AtomicBoolean running = new AtomicBoolean();

    @Override
    public void run(ApplicationArguments args) {
        cleanPending();
    }

    @Scheduled(fixedDelayString = "${app.media.cleanup-interval-ms:30000}")
    public void cleanPending() {
        if (!running.compareAndSet(false, true)) return;
        try {
            try {
                storageAttempts.recover();
            } catch (RuntimeException failure) {
                log.error("Failed to recover media storage attempts; retry scheduled ({})", failure.getClass().getSimpleName());
            }
            cleanClaimedSnapshot();
        } finally {
            running.set(false);
        }
    }

    private void cleanClaimedSnapshot() {
        List<String> storageKeys;
        try {
            storageKeys = work.pendingKeys();
        } catch (RuntimeException exception) {
            log.error("Failed to read media cleanup queue; startup will continue ({})", exception.getClass().getSimpleName());
            return;
        }

        for (String storageKey : storageKeys) {
            try {
                Integer references = work.referenceCount(storageKey);
                if (references != null && references > 0) continue;
                mediaStorage.delete(storageKey);
                work.deleteQueued(storageKey);
            } catch (Exception exception) {
                log.error("Failed to clean queued media. It will be retried ({})", exception.getClass().getSimpleName());
            }
        }
    }
}
