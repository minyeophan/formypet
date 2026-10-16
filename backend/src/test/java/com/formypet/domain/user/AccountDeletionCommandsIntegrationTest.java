package com.formypet.domain.user;

import com.formypet.domain.user.repository.jdbc.AccountDeletionCommands;
import com.formypet.support.IntegrationTestSupport;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.support.TransactionTemplate;
import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class AccountDeletionCommandsIntegrationTest extends IntegrationTestSupport {
    @Autowired AccountDeletionCommands commands;
    @Autowired JdbcTemplate jdbc;
    @Autowired TransactionTemplate transactions;

    @Test void cleanupAndAccountMutationRollbackTogetherOnFailure() {
        String email = UUID.randomUUID() + "@test.invalid";
        String provider = "cleanup-" + UUID.randomUUID();
        jdbc.update("INSERT INTO users(email,password_hash,nickname) VALUES (?,'hash','rollback')", email);
        long uid = jdbc.queryForObject("SELECT id FROM users WHERE email=?", Long.class, email);
        jdbc.update("""
                INSERT INTO support_tickets(requester_user_id,kind,request_id,payload_hash,category,title,content,created_at)
                VALUES (?,'INQUIRY','rollback',REPEAT('a',64),'BUG','title','body',UTC_TIMESTAMP(6))
                """, uid);
        long ticket = jdbc.queryForObject("SELECT id FROM support_tickets WHERE requester_user_id=?", Long.class, uid);
        jdbc.update("INSERT INTO support_mail_outbox(ticket_id,next_attempt_at) VALUES (?,UTC_TIMESTAMP(6))", ticket);
        try {
            assertThatThrownBy(() -> transactions.executeWithoutResult(status -> {
                commands.queueKakaoUnlink(provider);
                commands.deleteSupportData(uid);
                commands.markPending(uid);
                assertThat(commands.deletePendingUser(uid)).isEqualTo(1);
                throw new IllegalStateException("synthetic rollback");
            })).isInstanceOf(IllegalStateException.class).hasMessage("synthetic rollback");
            assertThat(jdbc.queryForObject("SELECT account_status FROM users WHERE id=?", String.class, uid)).isEqualTo("ACTIVE");
            assertThat(jdbc.queryForObject("SELECT auth_version FROM users WHERE id=?", Long.class, uid)).isZero();
            assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM support_tickets WHERE id=?", Integer.class, ticket)).isEqualTo(1);
            assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM support_mail_outbox WHERE ticket_id=?", Integer.class, ticket)).isEqualTo(1);
            assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM account_deletion_jobs WHERE provider_user_id=?", Integer.class, provider)).isZero();
        } finally {
            jdbc.update("DELETE FROM support_mail_outbox WHERE ticket_id=?", ticket);
            jdbc.update("DELETE FROM support_tickets WHERE id=?", ticket);
            jdbc.update("DELETE FROM users WHERE id=?", uid);
            jdbc.update("DELETE FROM account_deletion_jobs WHERE provider_user_id=?", provider);
        }
    }

    @Test void duplicateUnlinkQueueKeepsEarlierDeadlineAndRetryState() {
        String provider = "queue-" + UUID.randomUUID();
        try {
            jdbc.update("""
                    INSERT INTO account_deletion_jobs(provider_user_id,attempts,next_attempt_at,locked_until,last_error)
                    VALUES (?,3,'2020-01-01 01:02:03.123456','2030-01-01 01:02:03','Failure')
                    """, provider);
            commands.queueKakaoUnlink(provider);
            commands.queueKakaoUnlink(provider);
            var row = jdbc.queryForMap("SELECT * FROM account_deletion_jobs WHERE provider_user_id=?", provider);
            assertThat(row.get("attempts")).isEqualTo(3);
            assertThat(row.get("last_error")).isEqualTo("Failure");
            assertThat(jdbc.queryForObject("SELECT CAST(next_attempt_at AS CHAR) FROM account_deletion_jobs WHERE provider_user_id=?", String.class, provider))
                    .isEqualTo("2020-01-01 01:02:03.123456");
            assertThat(row.get("locked_until")).isNotNull();
        } finally {
            jdbc.update("DELETE FROM account_deletion_jobs WHERE provider_user_id=?", provider);
        }
    }
}
