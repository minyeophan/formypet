package com.formypet.domain.routine.service;

import com.formypet.domain.routine.dto.request.CareScheduleRequest;
import com.formypet.domain.routine.dto.response.CareScheduleResponse;
import java.util.List;

public interface CareScheduleService {
    CareScheduleResponse create(Long actorId, Long petId, CareScheduleRequest request);
    List<CareScheduleResponse> list(Long actorId, Long petId);
    CareScheduleResponse get(Long actorId, Long petId, Long scheduleId);
    CareScheduleResponse update(Long actorId, Long petId, Long scheduleId, CareScheduleRequest request);
    void delete(Long actorId, Long petId, Long scheduleId);
}
