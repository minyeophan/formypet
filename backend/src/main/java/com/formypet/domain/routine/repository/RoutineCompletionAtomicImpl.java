package com.formypet.domain.routine.repository;

import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import java.time.LocalDate;
import java.time.LocalDateTime;

/** Atomic unique-key mutations preserve record links and direct LocalDateTime JDBC binding. */
@RequiredArgsConstructor
public class RoutineCompletionAtomicImpl implements RoutineCompletionAtomic {
    private final JdbcTemplate jdbc;
    @PersistenceContext private EntityManager entityManager;

    @Override
    public void mark(Long routineId, Long petId, LocalDate date, String status, LocalDateTime completedAt,
                     LocalDateTime createdAt, LocalDateTime updatedAt) {
        entityManager.flush();
        jdbc.update("""
                INSERT INTO routine_completions (routine_id, pet_id, scheduled_date, status, completed_at, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE status=VALUES(status), completed_at=VALUES(completed_at), updated_at=VALUES(updated_at)
                """, routineId, petId, date, status, completedAt, createdAt, updatedAt);
        // Flush before mutation, clear afterward so reads cannot reuse stale completion snapshots.
        entityManager.clear();
    }

    @Override
    public void ensurePending(Long routineId, Long petId, LocalDate date, LocalDateTime createdAt, LocalDateTime updatedAt) {
        entityManager.flush();
        jdbc.update("""
                INSERT IGNORE INTO routine_completions (routine_id, pet_id, scheduled_date, status, created_at, updated_at)
                VALUES (?, ?, ?, 'PENDING', ?, ?)
                """, routineId, petId, date, createdAt, updatedAt);
        entityManager.clear();
    }
}
