package com.petyilgi.record.dto;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.Map;

public record ActivityRecordUpdateRequest(
        LocalDate date,
        LocalTime time,
        Long routineId,
        String note,
        Map<String, Object> detail
) {
}
