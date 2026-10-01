package com.formypet.media;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Slf4j
public class OrphanMediaCleanup {
    private final JdbcTemplate jdbc;

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void enqueue(String storageKey) {
        try {
            jdbc.update("INSERT IGNORE INTO media_cleanup_queue(storage_key) VALUES (?)", storageKey);
        } catch (RuntimeException failure) {
            // Do not expose a user's storage path in logs. Storage/DB outage needs reconciliation.
            log.error("Orphan media cleanup could not be queued; storage reconciliation required ({})",
                    failure.getClass().getSimpleName());
        }
    }
}
