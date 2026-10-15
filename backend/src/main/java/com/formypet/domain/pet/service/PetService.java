package com.formypet.domain.pet.service;

import com.formypet.domain.pet.dto.request.PetCreateRequest;
import com.formypet.domain.pet.dto.request.PetUpdateRequest;
import com.formypet.domain.pet.dto.response.PetResponse;
import java.util.List;

public interface PetService {
    PetResponse create(Long actorId, PetCreateRequest request);
    PetResponse get(Long actorId, Long petId);
    List<PetResponse> list(Long actorId);
    PetResponse update(Long actorId, Long petId, PetUpdateRequest request);
    void delete(Long actorId, Long petId);
}
