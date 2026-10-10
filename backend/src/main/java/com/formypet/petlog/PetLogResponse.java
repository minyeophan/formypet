package com.formypet.petlog;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;

public record PetLogResponse(long id, long petId, LocalDate date, LocalTime time, String note,
                             long version, List<PetLogPhotoResponse> photos, java.time.Instant createdAt,
                             Long appliedVersion) {
    public PetLogResponse withAppliedVersion(Long appliedVersion) {
        return new PetLogResponse(id,petId,date,time,note,version,photos,createdAt,appliedVersion);
    }
}
