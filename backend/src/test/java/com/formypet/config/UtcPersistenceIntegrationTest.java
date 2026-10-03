package com.formypet.config;

import com.formypet.auth.domain.User;
import com.formypet.auth.domain.RefreshToken;
import com.formypet.auth.repository.UserRepository;
import com.formypet.auth.repository.RefreshTokenRepository;
import com.formypet.support.IntegrationTestSupport;
import jakarta.persistence.EntityManager;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.util.TimeZone;
import java.util.UUID;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.support.TransactionTemplate;
import static org.assertj.core.api.Assertions.assertThat;

class UtcPersistenceIntegrationTest extends IntegrationTestSupport {
    @Autowired UserRepository users;
    @Autowired RefreshTokenRepository tokens;
    @Autowired JdbcTemplate jdbc;
    @Autowired EntityManager entityManager;
    @Autowired TransactionTemplate transactions;

    @ParameterizedTest
    @ValueSource(strings = {"UTC", "Asia/Seoul", "America/Los_Angeles"})
    void instantSurvivesJpaAndJdbcWithoutDependingOnJvmZone(String zone) {
        var original = TimeZone.getDefault();
        try {
            TimeZone.setDefault(TimeZone.getTimeZone(zone));
            transactions.executeWithoutResult(status -> {
                var before = Instant.now().minusSeconds(1);
                var user = users.saveAndFlush(User.create(UUID.randomUUID() + "@example.test", "hash", "utc-test"));
                var expiry = Instant.parse("2030-10-04T00:00:00Z");
                var token = tokens.saveAndFlush(RefreshToken.create(user, UUID.randomUUID().toString(), expiry));
                entityManager.clear();
                assertThat(users.findById(user.getId()).orElseThrow().getCreatedAt())
                        .isBetween(before, Instant.now().plusSeconds(1));
                assertThat(tokens.findById(token.getId()).orElseThrow().getExpiresAt()).isEqualTo(expiry);
                LocalDateTime storedExpiry = jdbc.queryForObject("SELECT expires_at FROM refresh_tokens WHERE id=?",
                        (rs, row) -> rs.getObject(1, LocalDateTime.class), token.getId());
                assertThat(storedExpiry).isEqualTo(LocalDateTime.ofInstant(expiry, ZoneOffset.UTC));
                assertThat(jdbc.queryForObject("SELECT @@session.time_zone", String.class)).isEqualTo("+00:00");
                status.setRollbackOnly();
            });
        } finally {
            TimeZone.setDefault(original);
        }
    }
}
