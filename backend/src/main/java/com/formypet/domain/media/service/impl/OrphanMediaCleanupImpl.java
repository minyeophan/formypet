package com.formypet.domain.media.service.impl;

import com.formypet.domain.media.service.OrphanMediaCleanup;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import com.formypet.domain.media.repository.jdbc.MediaWorkRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Slf4j
public class OrphanMediaCleanupImpl implements OrphanMediaCleanup {
    private final MediaWorkRepository work;

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void enqueue(String storageKey) {
        try {
            work.enqueue(storageKey);
        } catch (RuntimeException failure) {
            // Do not expose a user's storage path in logs. Storage/DB outage needs reconciliation.
            log.error("Orphan media cleanup could not be queued; storage reconciliation required ({})",
                    failure.getClass().getSimpleName());
        }
    }
}
