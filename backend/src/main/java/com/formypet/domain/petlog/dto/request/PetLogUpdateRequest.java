package com.formypet.domain.petlog.dto.request;

import com.formypet.domain.petlog.dto.request.PetLogCreateRequest;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;

public record PetLogUpdateRequest(LocalDate date, LocalTime time, String note, List<Long> mediaIds, long version) {
    public PetLogUpdateRequest {
        new PetLogCreateRequest(date, time, note, mediaIds);
    }
}
