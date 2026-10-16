package com.formypet.domain.user.scheduling;

import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import com.formypet.domain.user.service.KakaoUnlinkWebhookWorker;

@Component
@RequiredArgsConstructor
@ConditionalOnProperty(name = "app.account-deletion.webhook-scheduler-enabled", havingValue = "true", matchIfMissing = true)
public class KakaoUnlinkWebhookWorkerScheduler {
    private final KakaoUnlinkWebhookWorker worker;
    @Scheduled(fixedDelayString = "${app.account-deletion.webhook-interval-ms:5000}")
    public void dispatch() { worker.dispatch(); }
}
