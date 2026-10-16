package com.formypet.domain.routine.service;

import com.formypet.domain.routine.dto.request.*;
import com.formypet.domain.routine.dto.response.*;
import java.time.LocalDate;
import java.util.List;

public interface RoutineService {
    RoutineResponse create(Long actorId, Long petId, RoutineCreateRequest request);
    List<RoutineResponse> list(Long actorId, Long petId);
    RoutineResponse update(Long actorId, Long petId, Long routineId, RoutineUpdateRequest request);
    RoutineCompletionResponse markCompletion(Long actorId, Long petId, Long routineId, LocalDate date, RoutineCompletionRequest request);
    TodayRoutineResponse today(Long actorId, Long petId, LocalDate date);
    void delete(Long actorId, Long petId, Long routineId);
}
