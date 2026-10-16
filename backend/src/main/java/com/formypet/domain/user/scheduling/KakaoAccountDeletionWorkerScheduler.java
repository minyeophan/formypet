package com.formypet.domain.user.scheduling;

import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import com.formypet.domain.user.service.KakaoAccountDeletionWorker;

@Component
@RequiredArgsConstructor
@ConditionalOnProperty(name = "app.account-deletion.scheduler-enabled", havingValue = "true", matchIfMissing = true)
public class KakaoAccountDeletionWorkerScheduler {
    private final KakaoAccountDeletionWorker worker;
    @Scheduled(fixedDelayString = "${app.account-deletion.interval-ms:30000}")
    public void dispatch() { worker.dispatch(); }
    @Scheduled(fixedDelayString = "${app.account-deletion.monitor-interval-ms:3600000}")
    public void monitorPending() { worker.monitorPending(); }
}
