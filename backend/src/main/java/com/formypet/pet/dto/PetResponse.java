package com.formypet.pet.dto;

import com.formypet.pet.domain.Gender;
import com.formypet.pet.domain.Pet;

import java.math.BigDecimal;
import java.time.LocalDate;

public record PetResponse(
        Long id,
        String name,
        String species,
        LocalDate birthDate,
        String breed,
        LocalDate adoptionDate,
        Gender gender,
        BigDecimal weight,
        String animalRegistrationNumber,
        Boolean neutered,
        String diseases,
        String specialNotes,
        String guardianNickname,
        String specialStatus,
        String personality,
        String primaryHospitalName,
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
                pet.getBreed(),
                pet.getAdoptionDate(),
                pet.getGender(),
                pet.getWeight(),
                pet.getAnimalRegistrationNumber(),
                pet.getNeutered(),
                pet.getDiseases(),
                pet.getSpecialNotes(),
                pet.getGuardianNickname(),
                pet.getSpecialStatus(),
                pet.getPersonality(),
                pet.getPrimaryHospitalName(),
                pet.getAccentColor(),
                pet.getBgLight(),
                profileImageUrl
        );
    }
}
