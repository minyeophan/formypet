package com.formypet.domain.media;

import com.formypet.domain.media.repository.jdbc.MediaQuotaRepository;
import com.formypet.support.IntegrationTestSupport;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import static org.assertj.core.api.Assertions.assertThat;

@Transactional
class MediaQuotaRepositoryIntegrationTest extends IntegrationTestSupport {
    @Autowired MediaQuotaRepository quota;
    @Autowired JdbcTemplate jdbc;
    @Autowired org.springframework.transaction.support.TransactionTemplate transactions;

    @Test
    @Transactional(propagation = org.springframework.transaction.annotation.Propagation.NOT_SUPPORTED)
    void concurrentReservationsCannotBothConsumeTheLastSlot() throws Exception {
        long owner = user();
        var ready = new java.util.concurrent.CountDownLatch(2);
        var start = new java.util.concurrent.CountDownLatch(1);
        try (var workers = java.util.concurrent.Executors.newFixedThreadPool(2)) {
            java.util.concurrent.Callable<Integer> reserve = () -> {
                ready.countDown();
                if (!start.await(10, java.util.concurrent.TimeUnit.SECONDS)) throw new IllegalStateException("start timeout");
                return transactions.execute(tx -> quota.reserve(owner, 10, 1, 10, 1));
            };
            var first = workers.submit(reserve);
            var second = workers.submit(reserve);
            try {
                assertThat(ready.await(10, java.util.concurrent.TimeUnit.SECONDS)).isTrue();
            } finally {
                start.countDown();
            }
            assertThat(first.get(20, java.util.concurrent.TimeUnit.SECONDS)
                    + second.get(20, java.util.concurrent.TimeUnit.SECONDS)).isEqualTo(1);
            assertCounters(owner, 10, 1);
        } finally {
            jdbc.update("DELETE FROM users WHERE id=?", owner);
        }
    }

    @Test
    void reservesBothCountersAtomicallyAndAllowsProfileReplacementDifference() {
        long owner = user();
        assertThat(quota.reserve(owner, 100, 1, 100, 1)).isEqualTo(1);
        assertThat(quota.reserve(owner, 1, 0, 100, 1)).isZero();
        assertThat(quota.reserve(owner, -20, 1, 100, 1)).isZero();
        assertCounters(owner, 100, 1);
        assertThat(quota.reserve(owner, -20, 0, 100, 1)).isEqualTo(1);
        assertCounters(owner, 80, 1);
        assertThat(quota.reserve(owner, -81, 0, 100, 1)).isZero();
        assertCounters(owner, 80, 1);
    }

    @Test
    void decrementsWithZeroFloorAndLocksOnlyExistingOwners() {
        long owner = user();
        assertThat(quota.lockOwner(owner)).isTrue();
        assertThat(quota.lockOwner(-1L)).isFalse();
        quota.reserve(owner, 10, 1, 100, 5);
        quota.decrement(owner, 20, 2);
        assertCounters(owner, 0, 0);
        assertThat(quota.reserve(-1L, 10, 1, 100, 5)).isZero();
    }

    private void assertCounters(long owner, long bytes, int items) {
        Long actualBytes = jdbc.queryForObject("SELECT media_bytes_used FROM users WHERE id=?", Long.class, owner);
        Integer actualItems = jdbc.queryForObject("SELECT media_items_used FROM users WHERE id=?", Integer.class, owner);
        assertThat(actualBytes).isEqualTo(bytes);
        assertThat(actualItems).isEqualTo(items);
    }

    private long user() {
        String email = UUID.randomUUID() + "@media-quota.invalid";
        jdbc.update("INSERT INTO users(email,password_hash,nickname) VALUES (?,'unused','quota')", email);
        return jdbc.queryForObject("SELECT id FROM users WHERE email=?", Long.class, email);
    }
}
