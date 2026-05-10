package com.petyilgi.routine.dto;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;

public record RoutineUpdateRequest(
        String label,
        String typeId,
        String repeatType,
        List<Integer> days,
        Integer monthlyInterval,
        LocalDate startDate,
        LocalDate endDate,
        List<String> times,
        String note,
        Map<String, Object> detail,
        Boolean active,
        Boolean notificationEnabled
) {
}
