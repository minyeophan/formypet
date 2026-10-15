package com.formypet.domain.media.service;

public interface OrphanMediaCleanup {
    void enqueue(String storageKey);
}
