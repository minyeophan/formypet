package com.petyilgi.record.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.Map;

public record ActivityRecordCreateRequest(
        @NotBlank String typeId,
        @NotNull LocalDate date,
        LocalTime time,
        Long routineId,
        String note,
        Map<String, Object> detail
) {
}
