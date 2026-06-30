package com.petyilgi.routine.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.LocalDate;
import java.time.LocalTime;

public record CareScheduleRequest(
        @NotBlank String categoryId,
        @NotBlank @Size(max = 100) String title,
        @NotNull LocalDate startDate,
        LocalTime startTime,
        @NotNull LocalDate endDate,
        LocalTime endTime,
        boolean allDay,
        @Size(max = 200) String place,
        @Size(max = 500) String memo,
        @NotBlank String reminder
) {
}
