package com.petyilgi.pet;

import com.petyilgi.auth.domain.User;
import com.petyilgi.auth.repository.UserRepository;
import com.petyilgi.pet.domain.Pet;
import com.petyilgi.pet.dto.PetCreateRequest;
import com.petyilgi.pet.dto.PetResponse;
import com.petyilgi.pet.dto.PetUpdateRequest;
import com.petyilgi.pet.repository.PetRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class PetService {

    private static final String[] ACCENT_COLORS = {
            "#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4", "#FFEAA7",
            "#DDA0DD", "#98D8C8", "#F7DC6F", "#BB8FCE", "#85C1E9"
    };
    private static final String[] BG_LIGHTS = {
            "#FFE5E5", "#E0F7F5", "#E0F4FB", "#EAF7EE", "#FFF9E6",
            "#F5E6F5", "#E6F7F4", "#FEF9E7", "#F0E6F6", "#E8F4FD"
    };

    private final PetRepository petRepository;
    private final UserRepository userRepository;

    @Transactional
    public PetResponse create(String email, PetCreateRequest request) {
        User user = findUserByEmail(email);
        int colorIdx = (int) (petRepository.findByUserId(user.getId()).size() % ACCENT_COLORS.length);
        Pet pet = Pet.create(user, request.name(), request.species(), request.birthDate(),
                ACCENT_COLORS[colorIdx], BG_LIGHTS[colorIdx]);
        pet.update(request.name(), request.species(), request.birthDate(),
                request.gender(), request.weight(), request.animalRegistrationNumber(),
                request.neutered(), request.diseases(), request.specialNotes());
        return PetResponse.of(petRepository.save(pet));
    }

    @Transactional(readOnly = true)
    public List<PetResponse> list(String email) {
        User user = findUserByEmail(email);
        return petRepository.findByUserId(user.getId()).stream()
                .map(PetResponse::of)
                .toList();
    }

    @Transactional
    public PetResponse update(String email, Long petId, PetUpdateRequest request) {
        Pet pet = findOwnedPet(email, petId);
        pet.update(request.name(), request.species() != null ? request.species() : pet.getSpecies(),
                request.birthDate() != null ? request.birthDate() : pet.getBirthDate(),
                request.gender(), request.weight(), request.animalRegistrationNumber(),
                request.neutered(), request.diseases(), request.specialNotes());
        return PetResponse.of(pet);
    }

    @Transactional
    public void delete(String email, Long petId) {
        findOwnedPet(email, petId).softDelete();
    }

    private Pet findOwnedPet(String email, Long petId) {
        User user = findUserByEmail(email);
        return petRepository.findById(petId)
                .filter(p -> p.isOwnedBy(user.getId()))
                .orElseThrow(() -> new AccessDeniedException("해당 펫에 접근할 권한이 없습니다."));
    }

    private User findUserByEmail(String email) {
        return userRepository.findByEmail(email)
                .orElseThrow(() -> new IllegalStateException("사용자를 찾을 수 없습니다."));
    }
}
