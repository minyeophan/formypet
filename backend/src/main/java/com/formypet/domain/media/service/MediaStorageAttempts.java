package com.formypet.domain.media.service;

public interface MediaStorageAttempts {
    void begin(String key);
    void recover();
}
