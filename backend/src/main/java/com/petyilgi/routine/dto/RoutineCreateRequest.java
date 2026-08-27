package com.petyilgi.routine.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import io.swagger.v3.oas.annotations.media.Schema;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;

public record RoutineCreateRequest(
        @NotBlank @Schema(description = "루틴 이름") String label,
        @NotBlank @Schema(description = "활동 타입 ID") String typeId,
        @NotBlank @Schema(description = "반복 유형", allowableValues = {"daily", "weekly", "biweekly", "monthly"}) String repeatType,
        List<Integer> days,
        Integer monthlyInterval,
        @NotNull LocalDate startDate,
        LocalDate endDate,
        List<String> times,
        String note,
        Map<String, Object> detail,
        @Schema(description = "루틴 예약 알림 사용 여부", defaultValue = "true") Boolean notificationEnabled
) {
}
