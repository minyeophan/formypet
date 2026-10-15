package com.formypet.domain.pet.service.impl;

import com.formypet.auth.domain.User;
import com.formypet.auth.repository.UserRepository;
import com.formypet.domain.pet.entity.Pet;
import com.formypet.domain.pet.dto.request.PetCreateRequest;
import com.formypet.domain.pet.dto.response.PetResponse;
import com.formypet.domain.pet.dto.request.PetUpdateRequest;
import com.formypet.domain.pet.repository.PetRepository;
import com.formypet.domain.media.service.MediaService;
import lombok.RequiredArgsConstructor;
import com.formypet.domain.pet.repository.query.PetProfileImageQueryRepository;
import com.formypet.domain.pet.service.PetService;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;


import java.util.List;

@Service
@RequiredArgsConstructor
public class PetServiceImpl implements PetService {

    private final PetRepository petRepository;
    private final UserRepository userRepository;
    private final PetProfileImageQueryRepository profileImages;
    private final MediaService mediaService;

    @Transactional
    public PetResponse create(Long actorId, PetCreateRequest request) {
        User user = findUserById(actorId);
        Pet pet = Pet.create(user, request.name(), request.species(), request.birthDate(),
                request.accentColor(), request.bgLight(), petRepository.findByUserId(user.getId()).size());
        pet.update(request.name(), request.species(), request.birthDate(), false,
                request.gender(), request.weight(), request.animalRegistrationNumber(),
                request.neutered(), request.diseases(), request.specialNotes(),
                request.breed(), request.adoptionDate(), request.guardianNickname(),
                request.specialStatus(), request.personality(), request.primaryHospitalName(),
                request.accentColor(), request.bgLight());
        return PetResponse.of(petRepository.save(pet));
    }

    @Transactional(readOnly = true)
    public PetResponse get(Long actorId, Long petId) {
        return PetResponse.of(findOwnedPet(actorId, petId), latestPetMediaUrl(petId));
    }

    @Transactional(readOnly = true)
    public List<PetResponse> list(Long actorId) {
        User user = findUserById(actorId);
        return petRepository.findByUserId(user.getId()).stream()
                .map(pet -> PetResponse.of(pet, latestPetMediaUrl(pet.getId())))
                .toList();
    }

    @Transactional
    public PetResponse update(Long actorId, Long petId, PetUpdateRequest request) {
        Pet pet = findOwnedPet(actorId, petId);
        pet.update(request.name(), request.species(),
                request.birthDate(), request.birthDateUnknown(),
                request.gender(), request.weight(), request.animalRegistrationNumber(),
                request.neutered(), request.diseases(), request.specialNotes(),
                request.breed(), request.adoptionDate(), request.guardianNickname(),
                request.specialStatus(), request.personality(), request.primaryHospitalName(),
                request.accentColor(),
                request.bgLight());
        return PetResponse.of(pet, latestPetMediaUrl(pet.getId()));
    }

    @Transactional
    public void delete(Long actorId, Long petId) {
        Pet pet=findOwnedPet(actorId, petId);
        mediaService.deletePetLogDataForPet(actorId,petId);
        pet.softDelete();
    }

    private Pet findOwnedPet(Long actorId, Long petId) {
        User user = findUserById(actorId);
        if (petId == null) {
            throw new IllegalArgumentException("Pet id must not be null.");
        }
        return petRepository.findById(petId)
                .filter(p -> p.isOwnedBy(user.getId()))
                .orElseThrow(() -> new AccessDeniedException("해당 펫에 접근할 권한이 없습니다."));
    }

    private User findUserById(Long actorId) {
        return userRepository.findById(actorId)
                .orElseThrow(() -> new IllegalStateException("사용자를 찾을 수 없습니다."));
    }

    private String latestPetMediaUrl(Long petId) {
        return profileImages.findLatestId(petId).map(id -> "/api/v1/media/" + id).orElse(null);
    }
}
