package com.formypet.routine.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import io.swagger.v3.oas.annotations.media.Schema;

import java.time.LocalDate;
import java.time.LocalTime;

public record CareScheduleRequest(
        @NotBlank @Schema(description = "케어 일정 카테고리 ID") String categoryId,
        @NotBlank @Size(max = 100) @Schema(description = "일정 제목") String title,
        @NotNull LocalDate startDate,
        LocalTime startTime,
        @NotNull LocalDate endDate,
        LocalTime endTime,
        boolean allDay,
        @Size(max = 200) String place,
        @Size(max = 500) String memo,
        @NotBlank @Schema(description = "알림 시점", allowableValues = {"하루 전", "2시간 전", "1시간 전", "30분 전", "알림 없음", "1 day before", "2 hours before", "1 hour before", "30 minutes before", "none"}) String reminder
) {
}
