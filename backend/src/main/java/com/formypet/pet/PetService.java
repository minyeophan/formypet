package com.formypet.pet;

import com.formypet.auth.domain.User;
import com.formypet.auth.repository.UserRepository;
import com.formypet.pet.domain.Pet;
import com.formypet.pet.dto.PetCreateRequest;
import com.formypet.pet.dto.PetResponse;
import com.formypet.pet.dto.PetUpdateRequest;
import com.formypet.pet.repository.PetRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
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
    private final JdbcTemplate jdbcTemplate;

    @Transactional
    public PetResponse create(String email, PetCreateRequest request) {
        User user = findUserByEmail(email);
        int colorIdx = (int) (petRepository.findByUserId(user.getId()).size() % ACCENT_COLORS.length);
        String accentColor = fallbackIfBlank(request.accentColor(), ACCENT_COLORS[colorIdx]);
        String bgLight = fallbackIfBlank(request.bgLight(), BG_LIGHTS[colorIdx]);
        Pet pet = Pet.create(user, request.name(), request.species(), request.birthDate(),
                accentColor, bgLight);
        pet.update(request.name(), request.species(), request.birthDate(),
                request.gender(), request.weight(), request.animalRegistrationNumber(),
                request.neutered(), request.diseases(), request.specialNotes(),
                request.breed(), request.adoptionDate(), request.guardianNickname(),
                request.specialStatus(), request.personality(), request.primaryHospitalName(),
                accentColor, bgLight);
        return PetResponse.of(petRepository.save(pet));
    }

    @Transactional(readOnly = true)
    public List<PetResponse> list(String email) {
        User user = findUserByEmail(email);
        return petRepository.findByUserId(user.getId()).stream()
                .map(pet -> PetResponse.of(pet, latestPetMediaUrl(pet.getId())))
                .toList();
    }

    @Transactional
    public PetResponse update(String email, Long petId, PetUpdateRequest request) {
        Pet pet = findOwnedPet(email, petId);
        pet.update(request.name(), request.species() != null ? request.species() : pet.getSpecies(),
                resolveBirthDate(pet, request),
                request.gender(), request.weight(), request.animalRegistrationNumber(),
                request.neutered(), request.diseases(), request.specialNotes(),
                request.breed(), request.adoptionDate(), request.guardianNickname(),
                request.specialStatus(), request.personality(), request.primaryHospitalName(),
                fallbackIfBlank(request.accentColor(), pet.getAccentColor()),
                fallbackIfBlank(request.bgLight(), pet.getBgLight()));
        return PetResponse.of(pet, latestPetMediaUrl(pet.getId()));
    }

    @Transactional
    public void delete(String email, Long petId) {
        findOwnedPet(email, petId).softDelete();
    }

    private Pet findOwnedPet(String email, Long petId) {
        User user = findUserByEmail(email);
        if (petId == null) {
            throw new IllegalArgumentException("Pet id must not be null.");
        }
        return petRepository.findById(petId)
                .filter(p -> p.isOwnedBy(user.getId()))
                .orElseThrow(() -> new AccessDeniedException("해당 펫에 접근할 권한이 없습니다."));
    }

    private User findUserByEmail(String email) {
        return userRepository.findByEmail(email)
                .orElseThrow(() -> new IllegalStateException("사용자를 찾을 수 없습니다."));
    }

    private String latestPetMediaUrl(Long petId) {
        var ids = jdbcTemplate.queryForList("""
                SELECT id
                FROM media_resources
                WHERE pet_id = ? AND record_id IS NULL AND status = 'STORED'
                ORDER BY created_at DESC, id DESC
                LIMIT 1
                """, Long.class, petId);
        if (ids.isEmpty()) {
            return null;
        }
        return "/api/v1/media/" + ids.getFirst();
    }

    private String fallbackIfBlank(String value, String fallback) {
        return value == null || value.isBlank() ? fallback : value;
    }

    private LocalDate resolveBirthDate(Pet pet, PetUpdateRequest request) {
        if (Boolean.TRUE.equals(request.birthDateUnknown())) {
            return null;
        }
        if (request.birthDate() != null) {
            return request.birthDate();
        }
        return pet.getBirthDate();
    }
}
