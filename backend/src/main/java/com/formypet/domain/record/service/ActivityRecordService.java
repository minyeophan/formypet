package com.formypet.domain.record.service;

import com.formypet.domain.record.dto.request.ActivityRecordCreateRequest;
import com.formypet.domain.record.dto.request.ActivityRecordUpdateRequest;
import com.formypet.domain.record.dto.response.ActivityRecordResponse;
import java.time.LocalDate;
import java.util.List;

public interface ActivityRecordService {
    ActivityRecordResponse create(Long actorId, Long petId, ActivityRecordCreateRequest request);
    List<ActivityRecordResponse> list(Long actorId, Long petId, LocalDate date, String typeId, Integer limit);
    ActivityRecordResponse get(Long actorId, Long petId, Long recordId);
    ActivityRecordResponse update(Long actorId, Long petId, Long recordId, ActivityRecordUpdateRequest request);
    void delete(Long actorId, Long petId, Long recordId);
}
