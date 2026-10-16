package com.formypet.domain.user.service.impl;

import com.formypet.domain.user.client.KakaoAccountUnlinker;
import com.formypet.domain.user.service.KakaoAccountDeletionWorker;

import com.formypet.domain.user.entity.AccountCleanupRetry;
import com.formypet.domain.user.repository.jdbc.KakaoDeletionJobRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;
import java.util.concurrent.atomic.AtomicBoolean;

@Slf4j
@Component
@RequiredArgsConstructor
@ConditionalOnProperty(name = "app.account-deletion.scheduler-enabled", havingValue = "true", matchIfMissing = true)
public class KakaoAccountDeletionWorkerImpl implements KakaoAccountDeletionWorker {
    private final KakaoDeletionJobRepository jobs;
    private final KakaoAccountUnlinker unlinker;
    private final AtomicBoolean running = new AtomicBoolean();

    public void dispatch() {
        if (!unlinker.isConfigured()) return;
        processOne();
    }

    public void monitorPending() {
        var counts = jobs.counts();
        if (counts.total() > 0 && (!unlinker.isConfigured() || counts.overdue() > 0)) {
            // One day is an alert threshold, not a retention period or deletion promise.
            log.warn("Account cleanup needs operator attention: pending={}, olderThanOneDay={}, unlinkConfigured={}",
                    counts.total(), counts.overdue(), unlinker.isConfigured());
        }
    }

    public boolean processOne() {
        if (!running.compareAndSet(false, true)) return false;
        try {
            return jobs.withExclusiveLock(this::processClaimed);
        } finally { running.set(false); }
    }

    private boolean processClaimed(KakaoDeletionJobRepository.LockedSession session) {
        var job = session.claim();
        if (job == null) return false;
        try {
            unlinker.unlink(job.providerUserId());
            session.delete(job.id());
            return true;
        } catch (RuntimeException failure) {
            int attempts = session.attempts(job.id());
            session.reschedule(job.id(), AccountCleanupRetry.delaySeconds(attempts), failure.getClass().getSimpleName());
            log.warn("Kakao unlink retry scheduled: attempt={}, error={}", attempts + 1, failure.getClass().getSimpleName());
            return false;
        }
    }
}
