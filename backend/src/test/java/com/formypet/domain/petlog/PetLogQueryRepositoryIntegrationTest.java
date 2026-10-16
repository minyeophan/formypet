package com.formypet.domain.petlog;



import com.formypet.domain.petlog.entity.PetLog;
import com.formypet.domain.petlog.repository.PetLogRepository;
import com.formypet.domain.petlog.repository.PetLogQueryRepository;
import com.formypet.domain.petlog.repository.PetLogPreferenceRepository;
import com.formypet.support.IntegrationTestSupport;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import java.time.Instant;
import java.time.LocalDateTime;
import java.util.UUID;
import static org.assertj.core.api.Assertions.assertThat;

@Transactional
class PetLogQueryRepositoryIntegrationTest extends IntegrationTestSupport {
    @Autowired PetLogRepository logs;
    @Autowired PetLogQueryRepository queries;
    @Autowired PetLogPreferenceRepository preferences;
    @Autowired JdbcTemplate jdbc;

    private long[] ownerAndPet() {
        String email = UUID.randomUUID() + "@petlog-query.test";
        jdbc.update("INSERT INTO users(email,password_hash,nickname,registration_source) VALUES (?, 'hash', 'log', 'LOCAL')", email);
        long user = jdbc.queryForObject("SELECT id FROM users WHERE email=?", Long.class, email);
        jdbc.update("INSERT INTO pets(user_id,name,species,birth_date,accent_color,bg_light) VALUES (?, 'log', 'dog', '2022-01-01', '#123456', '#ffffff')", user);
        long pet = jdbc.queryForObject("SELECT id FROM pets WHERE user_id=?", Long.class, user);
        return new long[]{user, pet};
    }

    @Test
    void timelineUsesTimeThenIdCursorAndHalfOpenMonthRange() {
        long[] owner = ownerAndPet();
        LocalDateTime start = LocalDateTime.parse("2026-01-01T00:00");
        LocalDateTime end = start.plusMonths(1);
        var a = logs.saveAndFlush(PetLog.create(owner[0], owner[1], start, "a"));
        var b = logs.saveAndFlush(PetLog.create(owner[0], owner[1], start, "b"));
        logs.saveAndFlush(PetLog.create(owner[0], owner[1], end, "outside"));
        var first = queries.list(owner[1], start, end, null, null, 1);
        assertThat(first).hasSize(1);
        assertThat(first.getFirst().id()).isEqualTo(b.getId());
        var next = queries.list(owner[1], start, end, start, b.getId(), 2);
        assertThat(next).extracting(PetLogQueryRepository.LogRow::id).containsExactly(a.getId());
        assertThat(queries.find(a.getId(), owner[1]).orElseThrow().entryAt()).isEqualTo(start);
        assertThat(queries.find(a.getId(), owner[1] + 1)).isEmpty();
        assertThat(queries.years(owner[1])).containsExactly(2026);
        assertThat(queries.hasAny(owner[1])).isTrue();
    }

    @Test
    void preferenceUpsertPreservesOwnerAndExplicitUtcTimestamp() {
        long[] owner = ownerAndPet();
        Instant now = Instant.parse("2026-10-16T04:05:06.123456Z");
        assertThat(preferences.isDismissed(owner[0], owner[1])).isFalse();
        preferences.dismiss(owner[0], owner[1], now);
        assertThat(preferences.isDismissed(owner[0], owner[1])).isTrue();
        assertThat(preferences.isDismissed(owner[0] + 1, owner[1])).isFalse();
        assertThat(jdbc.queryForObject("SELECT updated_at FROM pet_log_preferences WHERE pet_id=?", LocalDateTime.class, owner[1]))
                .isEqualTo(LocalDateTime.parse("2026-10-16T04:05:06.123456"));
        preferences.dismiss(owner[0], owner[1]);
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM pet_log_preferences WHERE pet_id=?", Integer.class, owner[1])).isEqualTo(1);
    }
}
