package com.petyilgi.pet.dto;

import com.petyilgi.pet.domain.Gender;
import com.petyilgi.pet.domain.Pet;

import java.math.BigDecimal;
import java.time.LocalDate;

public record PetResponse(
        Long id,
        String name,
        String species,
        LocalDate birthDate,
        Gender gender,
        BigDecimal weight,
        String animalRegistrationNumber,
        Boolean neutered,
        String diseases,
        String specialNotes,
        String accentColor,
        String bgLight,
        String profileImageUrl
) {
    public static PetResponse of(Pet pet) {
        return of(pet, null);
    }

    public static PetResponse of(Pet pet, String profileImageUrl) {
        return new PetResponse(
                pet.getId(),
                pet.getName(),
                pet.getSpecies(),
                pet.getBirthDate(),
                pet.getGender(),
                pet.getWeight(),
                pet.getAnimalRegistrationNumber(),
                pet.getNeutered(),
                pet.getDiseases(),
                pet.getSpecialNotes(),
                pet.getAccentColor(),
                pet.getBgLight(),
                profileImageUrl
        );
    }
}
