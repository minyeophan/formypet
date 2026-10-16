package com.formypet.global;

import com.formypet.global.idempotency.repository.IdempotencyRepository;
import com.formypet.support.IntegrationTestSupport;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;
import java.util.UUID;
import static org.assertj.core.api.Assertions.assertThat;

class IdempotencyRepositoryIntegrationTest extends IntegrationTestSupport {
    @Autowired IdempotencyRepository receipts;
    @Autowired JdbcTemplate jdbc;
    @Autowired PlatformTransactionManager transactions;

    private long actor() {
        String email = UUID.randomUUID() + "@receipt.test";
        jdbc.update("INSERT INTO users(email,password_hash,nickname,registration_source) VALUES (?, 'hash', 'receipt', 'LOCAL')", email);
        return jdbc.queryForObject("SELECT id FROM users WHERE email=?", Long.class, email);
    }

    @Test @Transactional
    void currentReceiptPreservesNullableVersionAndFullCompositeKey() {
        long actor = actor();
        assertThat(receipts.findCurrent(actor, "create", "pet1", "key")).isEmpty();
        receipts.insert(actor, "create", "pet1", "key", "a".repeat(64), 123L, null);
        receipts.insert(actor, "update", "pet1", "key", "b".repeat(64), 123L, 7L);
        var create = receipts.findCurrent(actor, "create", "pet1", "key").orElseThrow();
        assertThat(create.hash()).isEqualTo("a".repeat(64));
        assertThat(create.resultId()).isEqualTo(123L);
        assertThat(create.resultVersion()).isNull();
        assertThat(receipts.findCurrent(actor, "update", "pet1", "key").orElseThrow().resultVersion()).isEqualTo(7L);
        assertThat(receipts.findCurrent(actor, "create", "pet2", "key")).isEmpty();
        jdbc.update("DELETE FROM idempotency_requests WHERE user_id=?", actor);
        assertThat(receipts.findCurrent(actor, "create", "pet1", "key")).isEmpty();
    }

    @Test
    void receiptRollsBackWithItsTransaction() {
        var tx = new TransactionTemplate(transactions);
        long actor = actor();
        try {
            tx.executeWithoutResult(status -> {
                receipts.insert(actor, "create", "pet", "rollback", "c".repeat(64), 9L, null);
                status.setRollbackOnly();
            });
            var persisted = tx.execute(status -> receipts.findCurrent(actor, "create", "pet", "rollback"));
            assertThat(persisted).isEmpty();
        } finally {
            jdbc.update("DELETE FROM users WHERE id=?", actor);
        }
    }
}
