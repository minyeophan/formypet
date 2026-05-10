package com.petyilgi.routine.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;

public record RoutineCreateRequest(
        @NotBlank String label,
        @NotBlank String typeId,
        @NotBlank String repeatType,
        List<Integer> days,
        Integer monthlyInterval,
        @NotNull LocalDate startDate,
        LocalDate endDate,
        List<String> times,
        String note,
        Map<String, Object> detail,
        Boolean notificationEnabled
) {
}
