package com.formypet.domain.user;

import com.formypet.domain.user.entity.UserBlock;
import com.formypet.domain.user.entity.UserBlockId;
import com.formypet.domain.user.repository.UserBlockRepository;
import com.formypet.support.IntegrationTestSupport;
import jakarta.persistence.EntityManager;
import java.time.Instant;
import java.time.LocalDateTime;
import java.util.UUID;
import org.hibernate.SessionFactory;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import static org.assertj.core.api.Assertions.assertThat;

@Transactional
class UserBlockRepositoryIntegrationTest extends IntegrationTestSupport {
    @Autowired UserBlockRepository blocks;
    @Autowired JdbcTemplate jdbc;
    @Autowired EntityManager entities;

    @Test void jpaMappingPreservesLegacyUtcAndDirectionalIdentity() {
        long actor = person("viewer"), target = person("target");
        var at = Instant.parse("2026-10-16T01:02:03.123456Z");
        blocks.saveAndFlush(UserBlock.create(actor, target, at));
        assertThat(jdbc.<LocalDateTime>queryForObject(
                "SELECT created_at FROM user_blocks WHERE blocker_user_id=? AND blocked_user_id=?",
                (rs, row) -> rs.getObject(1, LocalDateTime.class), actor, target))
                .isEqualTo(LocalDateTime.parse("2026-10-16T01:02:03.123456"));
        jdbc.update("INSERT INTO user_blocks(blocker_user_id,blocked_user_id,created_at) VALUES (?,?,'2026-10-15 23:59:59.654321')",
                target, actor);
        entities.clear();
        assertThat(blocks.findById(new UserBlockId(target, actor)).orElseThrow().getCreatedAt())
                .isEqualTo(LocalDateTime.parse("2026-10-15T23:59:59.654321"));
        assertThat(blocks.remove(actor, target)).isEqualTo(1);
        assertThat(blocks.remove(actor, target)).isZero();
        assertThat(blocks.existsById(new UserBlockId(target, actor))).isTrue();
    }

    @Test void duplicateKeepsTimestampAndListUsesCurrentNicknameWithOneQuery() {
        long actor = person("viewer"), older = person("old"), first = person("first"), second = person("second");
        for (long target : new long[]{older, first, second}) blocks.addIfAbsent(actor, target);
        jdbc.update("UPDATE user_blocks SET created_at='2026-10-16 01:02:03.123456' WHERE blocker_user_id=?", actor);
        jdbc.update("UPDATE user_blocks SET created_at='2026-10-15 01:02:03' WHERE blocker_user_id=? AND blocked_user_id=?", actor, older);
        blocks.addIfAbsent(actor, first);
        jdbc.update("UPDATE users SET nickname='changed' WHERE id=?", second);
        entities.clear();
        assertThat(blocks.findById(new UserBlockId(actor, first)).orElseThrow().getCreatedAt())
                .isEqualTo(LocalDateTime.parse("2026-10-16T01:02:03.123456"));
        entities.clear();
        var statistics = entities.getEntityManagerFactory().unwrap(SessionFactory.class).getStatistics();
        boolean enabled = statistics.isStatisticsEnabled();
        statistics.setStatisticsEnabled(true);
        statistics.clear();
        try {
            var rows = blocks.listBlocked(actor);
            assertThat(rows).extracting(row -> row.userId()).containsExactly(second, first, older);
            assertThat(rows.getFirst().nickname()).isEqualTo("changed");
            assertThat(statistics.getPrepareStatementCount()).isEqualTo(1);
            assertThat(statistics.getEntityLoadCount()).isZero();
            assertThat(statistics.getEntityFetchCount()).isZero();
        } finally {
            statistics.setStatisticsEnabled(enabled);
        }
        assertThat(blocks.listBlocked(second)).isEmpty();
    }

    private long person(String nickname) {
        String email = UUID.randomUUID() + "@test.invalid";
        jdbc.update("INSERT INTO users(email,password_hash,nickname) VALUES (?,'hash',?)", email, nickname);
        return jdbc.queryForObject("SELECT id FROM users WHERE email=?", Long.class, email);
    }
}
