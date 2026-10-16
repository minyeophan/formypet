package com.formypet.domain.petlog;



import com.formypet.domain.petlog.entity.PetLog;
import com.formypet.domain.petlog.repository.PetLogRepository;
import com.formypet.support.IntegrationTestSupport;
import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import java.time.Instant;
import java.time.LocalDateTime;
import java.util.UUID;
import static org.assertj.core.api.Assertions.assertThat;

@Transactional
class PetLogRepositoryIntegrationTest extends IntegrationTestSupport {
    @Autowired PetLogRepository logs;
    @Autowired JdbcTemplate jdbc;
    @Autowired EntityManager entities;

    private long[] ownerAndPet() {
        String email = UUID.randomUUID() + "@petlog.test";
        jdbc.update("INSERT INTO users(email,password_hash,nickname,registration_source) VALUES (?, 'hash', 'log', 'LOCAL')", email);
        long user = jdbc.queryForObject("SELECT id FROM users WHERE email=?", Long.class, email);
        jdbc.update("INSERT INTO pets(user_id,name,species,birth_date,accent_color,bg_light) VALUES (?, 'log', 'dog', '2022-01-01', '#123456', '#ffffff')", user);
        long pet = jdbc.queryForObject("SELECT id FROM pets WHERE user_id=?", Long.class, user);
        return new long[]{user, pet};
    }

    @Test
    void createUpdateAndDeletePreserveLocalTimeUtcAndVersionOnUnchangedContent() {
        long[] owner = ownerAndPet();
        LocalDateTime entry = LocalDateTime.parse("2026-01-01T09:10:11.123456");
        Instant changed = Instant.parse("2026-10-16T04:05:06.123456Z");
        var log = logs.saveAndFlush(PetLog.create(owner[0], owner[1], entry, "note"));
        assertThat(jdbc.queryForObject("SELECT entry_at FROM pet_logs WHERE id=?", LocalDateTime.class, log.getId())).isEqualTo(entry);
        assertThat(log.getVersion()).isZero();
        var current = logs.findCurrent(log.getId(), owner[1]).orElseThrow();
        assertThat(current.getCreatedAt()).isNotNull();
        current.revise(entry, "note", changed);
        logs.flush();
        assertThat(jdbc.queryForObject("SELECT version FROM pet_logs WHERE id=?", Long.class, log.getId())).isEqualTo(1);
        assertThat(jdbc.queryForObject("SELECT updated_at FROM pet_logs WHERE id=?", LocalDateTime.class, log.getId()))
                .isEqualTo(LocalDateTime.parse("2026-10-16T04:05:06.123456"));
        assertThat(logs.findCurrent(log.getId(), owner[1] + 1)).isEmpty();
        logs.delete(current);
        logs.flush();
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM pet_logs WHERE id=?", Integer.class, log.getId())).isZero();
    }

    @Test
    void currentReadRefreshesPreviouslyManagedVersionAfterSqlChange() {
        long[] owner = ownerAndPet();
        var log = logs.saveAndFlush(PetLog.create(owner[0], owner[1], LocalDateTime.parse("2026-01-01T09:00"), "old"));
        jdbc.update("UPDATE pet_logs SET version=7,note='current' WHERE id=?", log.getId());
        assertThat(log.getVersion()).isZero();
        var current = logs.findCurrent(log.getId(), owner[1]).orElseThrow();
        assertThat(current).isSameAs(log);
        assertThat(current.getVersion()).isEqualTo(7);
        assertThat(current.getNote()).isEqualTo("current");
        current.revise(current.getEntryAt(), "latest", Instant.now());
        logs.flush();
        assertThat(jdbc.queryForObject("SELECT version FROM pet_logs WHERE id=?", Long.class, log.getId())).isEqualTo(8);
    }
}
