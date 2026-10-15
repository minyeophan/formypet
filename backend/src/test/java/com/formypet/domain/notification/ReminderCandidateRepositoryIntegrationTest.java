package com.formypet.domain.notification;

import com.formypet.domain.notification.repository.query.ReminderCandidateRepository;
import com.formypet.support.IntegrationTestSupport;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import static org.assertj.core.api.Assertions.*;

@Transactional
class ReminderCandidateRepositoryIntegrationTest extends IntegrationTestSupport {
    @Autowired ReminderCandidateRepository candidates;
    @Autowired JdbcTemplate jdbc;

    @Test void dispatchCandidatesRespectRecipientPreferencesPetDeletionAndRoutineFlags() {
        var email = UUID.randomUUID() + "@reminder-candidate.test";
        jdbc.update("INSERT INTO users(email,password_hash,nickname) VALUES (?,'test','test')", email);
        long user = jdbc.queryForObject("SELECT id FROM users WHERE email=?", Long.class, email);
        jdbc.update("INSERT INTO pets(user_id,name,species,accent_color,bg_light) VALUES (?,'pet','dog','#000000','#ffffff')", user);
        long pet = jdbc.queryForObject("SELECT id FROM pets WHERE user_id=?", Long.class, user);
        jdbc.update("""
                INSERT INTO routines(pet_id,label,type_id,repeat_type,days,monthly_interval,start_date,times,notification_enabled)
                VALUES (?,'label','water','daily','[]',1,'2026-09-18','["09:00"]',TRUE)
                """, pet);
        long routine = jdbc.queryForObject("SELECT id FROM routines WHERE pet_id=?", Long.class, pet);
        jdbc.update("""
                INSERT INTO care_schedules(pet_id,category_id,title,start_date,end_date,reminder)
                VALUES (?,'hospital','care','2026-09-18','2026-09-18','1시간 전')
                """, pet);
        long care = jdbc.queryForObject("SELECT id FROM care_schedules WHERE pet_id=?", Long.class, pet);
        assertThat(candidates.careSchedule(user, care)).get().satisfies(row -> {
            assertThat(row.startDate()).isEqualTo(LocalDate.of(2026, 9, 18));
            assertThat(row.startTime()).isNull();
            assertThat(row.reminder()).isEqualTo("1시간 전");
        });
        assertThat(candidates.careSchedule(user + 1, care)).isEmpty();
        jdbc.update("UPDATE care_schedules SET start_time='09:07:00' WHERE id=?", care);
        assertThat(candidates.careSchedule(user, care).orElseThrow().startTime()).isEqualTo(LocalTime.of(9, 7));
        assertThat(candidates.careSchedules()).extracting(row -> row.id()).contains(care);
        assertThat(candidates.routine(user, routine)).get().satisfies(row -> {
            assertThat(row.startDate()).isEqualTo(LocalDate.of(2026, 9, 18));
            assertThat(row.times()).isEqualTo("[\"09:00\"]");
            assertThat(row.petName()).isEqualTo("pet");
        });
        assertThat(candidates.routines()).extracting(row -> row.id()).contains(routine);
        assertThat(candidates.routine(user + 1, routine)).isEmpty();
        jdbc.update("UPDATE routines SET notification_enabled=FALSE WHERE id=?", routine);
        assertThat(candidates.routine(user, routine)).isEmpty();
        jdbc.update("UPDATE routines SET notification_enabled=TRUE,is_active=FALSE WHERE id=?", routine);
        assertThat(candidates.routine(user, routine)).isEmpty();
        jdbc.update("UPDATE routines SET is_active=TRUE WHERE id=?", routine);
        jdbc.update("UPDATE users SET notification_enabled=FALSE WHERE id=?", user);
        assertThat(candidates.routine(user, routine)).isEmpty();
        assertThat(candidates.careSchedule(user, care)).isEmpty();
        jdbc.update("UPDATE users SET notification_enabled=TRUE WHERE id=?", user);
        jdbc.update("UPDATE pets SET is_deleted=TRUE WHERE id=?", pet);
        assertThat(candidates.routine(user, routine)).isEmpty();
        assertThat(candidates.careSchedule(user, care)).isEmpty();
    }
}
