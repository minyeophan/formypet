package com.formypet.routine.dto;

import java.time.LocalDate;
import java.time.Instant;

public record RoutineCompletionResponse(
        Long id,
        Long routineId,
        Long petId,
        LocalDate scheduledDate,
        String status,
        Instant completedAt
) {
    public static RoutineCompletionResponse of(Long id, Long routineId, Long petId,
                                               LocalDate scheduledDate, String status,
                                               Instant completedAt) {
        return new RoutineCompletionResponse(id, routineId, petId, scheduledDate, status, completedAt);
    }
}
