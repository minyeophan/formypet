package com.formypet.domain.media.service.impl;

import com.formypet.domain.media.service.MediaStorageAttempts;

import lombok.RequiredArgsConstructor;
import com.formypet.domain.media.repository.jdbc.MediaWorkRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/** Durable intent precedes I/O; the writer holds the intent row lock until its DB transaction ends. */
@Service
@RequiredArgsConstructor
public class MediaStorageAttemptsImpl implements MediaStorageAttempts {
    private final MediaWorkRepository work;

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void begin(String key) {
        work.beginAttempt(key);
    }

    @Transactional
    public void recover() {
        var keys = work.abandonedKeys();
        for (String key : keys) {
            Integer references = work.referenceCount(key);
            if (references != null && references == 0) {
                work.enqueue(key);
            }
            work.finishAttempt(key);
        }
    }
}
