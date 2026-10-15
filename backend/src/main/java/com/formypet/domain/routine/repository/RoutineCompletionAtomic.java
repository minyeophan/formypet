package com.formypet.domain.routine.repository;

import java.time.LocalDate;
import java.time.LocalDateTime;

public interface RoutineCompletionAtomic {
    void mark(Long routineId, Long petId, LocalDate date, String status, LocalDateTime completedAt,
              LocalDateTime createdAt, LocalDateTime updatedAt);
    void ensurePending(Long routineId, Long petId, LocalDate date, LocalDateTime createdAt, LocalDateTime updatedAt);
}
