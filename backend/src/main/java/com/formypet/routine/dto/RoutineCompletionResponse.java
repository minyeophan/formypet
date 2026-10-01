package com.formypet.routine.dto;

import java.time.LocalDate;
import java.time.LocalDateTime;

public record RoutineCompletionResponse(
        Long id,
        Long routineId,
        Long petId,
        LocalDate scheduledDate,
        String status,
        LocalDateTime completedAt
) {
    public static RoutineCompletionResponse of(Long id, Long routineId, Long petId,
                                               LocalDate scheduledDate, String status,
                                               LocalDateTime completedAt) {
        return new RoutineCompletionResponse(id, routineId, petId, scheduledDate, status, completedAt);
    }
}
