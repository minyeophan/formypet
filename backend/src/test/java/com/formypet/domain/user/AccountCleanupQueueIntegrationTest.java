package com.formypet.domain.user;

import com.formypet.domain.user.client.KakaoAccountUnlinker;
import com.formypet.domain.user.service.impl.KakaoAccountDeletionWorkerImpl;

import com.formypet.domain.user.repository.jdbc.KakaoDeletionJobRepository;
import com.formypet.domain.user.repository.jdbc.KakaoWebhookRepository;
import com.formypet.support.IntegrationTestSupport;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.support.TransactionTemplate;
import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class AccountCleanupQueueIntegrationTest extends IntegrationTestSupport {
    @Autowired KakaoDeletionJobRepository jobs;
    @Autowired KakaoWebhookRepository events;
    @Autowired JdbcTemplate jdbc;
    @Autowired TransactionTemplate transactions;

    @Test void advisoryLockExcludesOtherConnectionAndReleasesAfterFailure() throws Exception {
        jdbc.update("DELETE FROM account_deletion_jobs");
        jdbc.update("INSERT INTO account_deletion_jobs(provider_user_id,next_attempt_at) VALUES ('queue-lock',UTC_TIMESTAMP(6))");
        try (var executor = Executors.newSingleThreadExecutor()) {
            assertThatThrownBy(() -> jobs.withExclusiveLock(session -> {
                var job = session.claim();
                assertThat(job.providerUserId()).isEqualTo("queue-lock");
                try {
                    assertThat(executor.submit(() -> jobs.withExclusiveLock(other -> true)).get(10, TimeUnit.SECONDS)).isFalse();
                } catch (Exception failure) {
                    throw new AssertionError(failure);
                }
                throw new IllegalStateException("synthetic callback failure");
            })).isInstanceOf(org.springframework.dao.InvalidDataAccessApiUsageException.class)
                    .hasCauseInstanceOf(IllegalStateException.class).hasMessage("synthetic callback failure");
            assertThat(jdbc.queryForObject("SELECT IS_FREE_LOCK(CONCAT(DATABASE(), ':kakao-unlink'))", Integer.class)).isEqualTo(1);
            // Use another physical connection to prove the first session released its advisory lock.
            assertThat(executor.submit(() -> jobs.withExclusiveLock(session -> true)).get(10, TimeUnit.SECONDS)).isTrue();
        } finally {
            jdbc.update("DELETE FROM account_deletion_jobs WHERE provider_user_id='queue-lock'");
        }
    }

    @Test void providerFailureReschedulesAndStoresOnlyExceptionClass() {
        jdbc.update("DELETE FROM account_deletion_jobs");
        jdbc.update("INSERT INTO account_deletion_jobs(provider_user_id,next_attempt_at) VALUES ('queue-failure',UTC_TIMESTAMP(6))");
        var unlinker = new com.formypet.domain.user.client.KakaoAccountUnlinker() {
            public boolean isConfigured() { return true; }
            public void unlink(String id) { throw new IllegalArgumentException("private provider response"); }
        };
        try {
            var worker = new com.formypet.domain.user.service.impl.KakaoAccountDeletionWorkerImpl(jobs, unlinker);
            assertThat(worker.processOne()).isFalse();
            assertThat(jdbc.queryForObject("SELECT attempts FROM account_deletion_jobs WHERE provider_user_id='queue-failure'", Integer.class)).isEqualTo(1);
            assertThat(jdbc.queryForObject("SELECT last_error FROM account_deletion_jobs WHERE provider_user_id='queue-failure'", String.class)).isEqualTo("IllegalArgumentException");
            assertThat(jdbc.queryForObject("SELECT locked_until IS NULL FROM account_deletion_jobs WHERE provider_user_id='queue-failure'", Boolean.class)).isTrue();
            assertThat(jdbc.queryForObject("SELECT TIMESTAMPDIFF(SECOND,UTC_TIMESTAMP(6),next_attempt_at) FROM account_deletion_jobs WHERE provider_user_id='queue-failure'", Long.class)).isBetween(25L, 30L);
            assertThat(jobs.counts().total()).isEqualTo(1);
            assertThat(jobs.counts().overdue()).isZero();
            assertThat(worker.processOne()).isFalse();
            assertThat(jdbc.queryForObject("SELECT IS_FREE_LOCK(CONCAT(DATABASE(), ':kakao-unlink'))", Integer.class)).isEqualTo(1);
        } finally {
            jdbc.update("DELETE FROM account_deletion_jobs WHERE provider_user_id='queue-failure'");
        }
    }

    @Test void webhookClaimAndReschedulePreserveIdentityLeaseAndRetryState() {
        jdbc.update("DELETE FROM kakao_unlink_webhook_events");
        try {
            events.enqueue("12345");
            events.enqueue("12345");
            var event = transactions.execute(status -> events.claim());
            assertThat(event).isNotNull();
            assertThat(event.providerUserId()).isEqualTo("12345");
            assertThat(event.attempts()).isZero();
            assertThat(transactions.<KakaoWebhookRepository.Event>execute(status -> events.claim())).isNull();
            transactions.executeWithoutResult(status -> {
                assertThat(events.lockEvent(event.id(), "99999")).isFalse();
                assertThat(events.lockEvent(event.id(), "12345")).isTrue();
            });
            events.reschedule(event.id(), 1, 30, "SyntheticFailure");
            assertThat(jdbc.queryForObject("SELECT attempts FROM kakao_unlink_webhook_events WHERE id=?", Integer.class, event.id())).isEqualTo(1);
            assertThat(jdbc.queryForObject("SELECT locked_until IS NULL FROM kakao_unlink_webhook_events WHERE id=?", Boolean.class, event.id())).isTrue();
            assertThat(jdbc.queryForObject("SELECT TIMESTAMPDIFF(SECOND,UTC_TIMESTAMP(6),next_attempt_at) FROM kakao_unlink_webhook_events WHERE id=?", Long.class, event.id())).isBetween(25L, 30L);
            assertThat(jdbc.queryForObject("SELECT last_error FROM kakao_unlink_webhook_events WHERE id=?", String.class, event.id())).isEqualTo("SyntheticFailure");
            assertThat(transactions.<KakaoWebhookRepository.Event>execute(status -> events.claim())).isNull();
            transactions.executeWithoutResult(status -> events.delete(event.id()));
            assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM kakao_unlink_webhook_events", Integer.class)).isZero();
        } finally {
            jdbc.update("DELETE FROM kakao_unlink_webhook_events");
        }
    }
}
