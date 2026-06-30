package com.petyilgi.routine.dto;

import java.time.LocalDate;
import java.time.LocalDateTime;

public record CareScheduleResponse(
        Long id,
        Long petId,
        String categoryId,
        String title,
        LocalDate startDate,
        String startTime,
        LocalDate endDate,
        String endTime,
        boolean allDay,
        String place,
        String memo,
        String reminder,
        LocalDateTime createdAt
) {
    public static CareScheduleResponse of(Long id, Long petId, String categoryId, String title,
                                          LocalDate startDate, String startTime,
                                          LocalDate endDate, String endTime,
                                          boolean allDay, String place, String memo,
                                          String reminder, LocalDateTime createdAt) {
        return new CareScheduleResponse(
                id,
                petId,
                categoryId,
                title,
                startDate,
                allDay ? null : startTime,
                endDate,
                allDay ? null : endTime,
                allDay,
                place,
                memo,
                reminder,
                createdAt
        );
    }
}
