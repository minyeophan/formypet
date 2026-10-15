package com.formypet.domain.media.storage;

import com.formypet.domain.media.storage.MediaStorage;
import com.formypet.domain.media.service.OrphanMediaCleanup;
import java.io.IOException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

@Component
@RequiredArgsConstructor
@Slf4j
public class MediaRollbackCleanup {
    private final MediaStorage mediaStorage;
    private final OrphanMediaCleanup orphanCleanup;

    public void registerRollbackCleanup(String storageKey) {
        if (!TransactionSynchronizationManager.isSynchronizationActive()) {
            return;
        }
        TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
            @Override
            public void afterCompletion(int status) {
                if (status == STATUS_ROLLED_BACK) {
                    deleteQuietly(storageKey);
                }
            }
        });
    }

    public void deleteQuietly(String storageKey) {
        try {
            mediaStorage.delete(storageKey);
        } catch (IOException failure) {
            try {
                orphanCleanup.enqueue(storageKey);
            } catch (RuntimeException queueFailure) {
                // A separately committed storage attempt remains recoverable even if enqueue commit fails.
                log.error("Media cleanup enqueue failed; durable attempt will be recovered ({})",
                        queueFailure.getClass().getSimpleName());
            }
        }
    }
}
