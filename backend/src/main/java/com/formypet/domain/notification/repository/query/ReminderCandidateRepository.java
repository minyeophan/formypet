package com.formypet.domain.notification.repository.query;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

/** Cross-domain reads only; recurrence and eligibility decisions belong to services/domain rules. */
@Repository
@RequiredArgsConstructor
public class ReminderCandidateRepository {
    private final JdbcTemplate jdbc;
    private static final String ROUTINES = """
            SELECT r.id,r.label,r.repeat_type,r.days,r.monthly_interval,r.start_date,r.end_date,r.times,
                   p.name,u.id AS user_id
            FROM routines r JOIN pets p ON p.id=r.pet_id JOIN users u ON u.id=p.user_id
            WHERE r.is_active=1 AND r.notification_enabled=1 AND u.notification_enabled=1 AND p.is_deleted=0
            """;
    private static final String CARE = """
            SELECT c.id,c.title,c.start_date,c.start_time,c.reminder,p.name,u.id AS user_id
            FROM care_schedules c JOIN pets p ON p.id=c.pet_id JOIN users u ON u.id=p.user_id
            WHERE p.is_deleted=0 AND u.notification_enabled=1
            """;
    private static final RowMapper<RoutineReminderCandidate> ROUTINE_ROW = (rs, row) ->
            new RoutineReminderCandidate(rs.getLong("id"), rs.getLong("user_id"), rs.getString("label"),
                    rs.getString("name"), rs.getString("repeat_type"), rs.getString("days"), rs.getString("times"),
                    rs.getInt("monthly_interval"), rs.getObject("start_date", LocalDate.class), rs.getObject("end_date", LocalDate.class));
    private static final RowMapper<CareReminderCandidate> CARE_ROW = (rs, row) -> {
        var time = rs.getTime("start_time");
        return new CareReminderCandidate(rs.getLong("id"), rs.getLong("user_id"), rs.getString("title"),
                rs.getString("name"), rs.getObject("start_date", LocalDate.class), time == null ? null : time.toLocalTime(), rs.getString("reminder"));
    };

    public List<RoutineReminderCandidate> routines() { return jdbc.query(ROUTINES, ROUTINE_ROW); }
    public Optional<RoutineReminderCandidate> routine(Long userId, Long id) {
        return jdbc.query(ROUTINES + " AND r.id=? AND u.id=?", ROUTINE_ROW, id, userId).stream().findFirst();
    }
    public List<CareReminderCandidate> careSchedules() { return jdbc.query(CARE, CARE_ROW); }
    public Optional<CareReminderCandidate> careSchedule(Long userId, Long id) {
        return jdbc.query(CARE + " AND c.id=? AND u.id=?", CARE_ROW, id, userId).stream().findFirst();
    }
}
