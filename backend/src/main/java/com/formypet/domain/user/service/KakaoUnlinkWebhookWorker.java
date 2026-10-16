package com.formypet.domain.user.service;

public interface KakaoUnlinkWebhookWorker {
    void dispatch();
    boolean processOne();
}
