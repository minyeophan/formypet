package com.formypet.domain.user.service.impl;

import com.formypet.domain.user.service.KakaoUnlinkWebhookEventProcessor;
import com.formypet.domain.user.service.KakaoUnlinkWebhookWorker;

import com.formypet.domain.user.entity.AccountCleanupRetry;
import com.formypet.domain.user.repository.jdbc.KakaoWebhookRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;
import java.util.concurrent.atomic.AtomicBoolean;

@Slf4j
@Component
@RequiredArgsConstructor
@ConditionalOnProperty(name = "app.account-deletion.webhook-scheduler-enabled", havingValue = "true", matchIfMissing = true)
public class KakaoUnlinkWebhookWorkerImpl implements KakaoUnlinkWebhookWorker {
    private final KakaoWebhookRepository events;
    private final PlatformTransactionManager transactionManager;
    private final KakaoUnlinkWebhookEventProcessor processor;
    private final AtomicBoolean running = new AtomicBoolean();

    public void dispatch() { processOne(); }

    public boolean processOne() {
        if (!running.compareAndSet(false, true)) return false;
        try {
            var tx = new TransactionTemplate(transactionManager);
            var event = tx.execute(status -> events.claim());
            if (event == null) return false;
            try {
                processor.process(event.id(), event.providerUserId());
                return true;
            } catch (RuntimeException failure) {
                int attempts = AccountCleanupRetry.nextWebhookAttempt(event.attempts());
                events.reschedule(event.id(), attempts, AccountCleanupRetry.delaySeconds(attempts - 1),
                        failure.getClass().getSimpleName());
                log.warn("Kakao unlink webhook retry scheduled: attempt={}, error={}", attempts, failure.getClass().getSimpleName());
                return false;
            }
        } finally { running.set(false); }
    }
}
