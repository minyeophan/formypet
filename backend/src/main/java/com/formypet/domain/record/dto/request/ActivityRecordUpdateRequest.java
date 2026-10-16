package com.formypet.domain.record.dto.request;

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
