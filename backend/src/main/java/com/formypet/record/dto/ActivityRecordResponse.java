package com.formypet.record.dto;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.Map;

public record ActivityRecordResponse(
        Long id,
        Long petId,
        String typeId,
        LocalDate date,
        LocalTime time,
        Long routineId,
        String note,
        List<String> mediaUrls,
        Map<String, Object> detail
) {
    public static ActivityRecordResponse of(Long id, Long petId, String typeId, LocalDate date,
                                            LocalTime time, Long routineId, String note, List<String> mediaUrls,
                                            Map<String, Object> detail) {
        return new ActivityRecordResponse(id, petId, typeId, date, time, routineId, note, mediaUrls, detail);
    }
}
