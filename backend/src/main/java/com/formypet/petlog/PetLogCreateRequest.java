package com.formypet.petlog;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;

public record PetLogCreateRequest(LocalDate date, LocalTime time, String note, List<Long> mediaIds) {
    public PetLogCreateRequest {
        if (date == null || time == null) throw new IllegalArgumentException("기록 날짜와 시간을 입력해 주세요.");
        if (note != null && note.length() > 2000) throw new IllegalArgumentException("글은 2,000자 이내로 입력해 주세요.");
        if (mediaIds == null || mediaIds.isEmpty() || mediaIds.size() > 10 || mediaIds.stream().anyMatch(java.util.Objects::isNull)
                || mediaIds.stream().distinct().count() != mediaIds.size()) {
            throw new IllegalArgumentException("사진은 1장 이상 10장 이하로 선택해 주세요.");
        }
    }
}
