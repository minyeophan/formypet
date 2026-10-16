package com.formypet.domain.petlog.service;

import com.formypet.domain.petlog.dto.request.*;
import com.formypet.domain.petlog.dto.response.*;

public interface PetLogService {
    PetLogResponse create(Long userId, Long petId, PetLogCreateRequest request);
    PetLogPageResponse list(Long userId, Long petId, Integer year, Integer month, int limit, String cursor);
    PetLogResponse get(Long userId, Long petId, Long id);
    PetLogResponse update(Long userId, Long petId, Long id, PetLogUpdateRequest request);
    void delete(Long userId, Long petId, Long id, long expectedVersion);
    boolean dismissExample(Long userId, Long petId);
    boolean exampleDismissed(Long userId, Long petId);
}
