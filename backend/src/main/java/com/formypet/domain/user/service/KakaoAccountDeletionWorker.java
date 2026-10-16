package com.formypet.domain.user.service;

public interface KakaoAccountDeletionWorker {
    void dispatch();
    void monitorPending();
    boolean processOne();
}
