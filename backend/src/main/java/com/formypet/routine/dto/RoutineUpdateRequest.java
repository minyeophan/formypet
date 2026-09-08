package com.formypet.routine.dto;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import io.swagger.v3.oas.annotations.media.Schema;

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
        @Schema(description = "루틴 예약 알림 사용 여부") Boolean notificationEnabled,
        @Schema(description = "true면 종료일을 제거합니다. 생략 시 기존 종료일을 유지합니다.") Boolean clearEndDate
) {
}
