package com.formypet.pet.dto;

import com.formypet.pet.domain.Gender;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.time.LocalDate;

public record PetUpdateRequest(
        @NotBlank @Size(max = 50) String name,
        @Size(max = 30) String species,
        LocalDate birthDate,
        Boolean birthDateUnknown,
        @Size(max = 80) String breed,
        LocalDate adoptionDate,
        Gender gender,
        BigDecimal weight,
        @Size(max = 20) String animalRegistrationNumber,
        Boolean neutered,
        String diseases,
        String specialNotes,
        @Size(max = 30) String guardianNickname,
        @Size(max = 30) String specialStatus,
        String personality,
        @Size(max = 100) String primaryHospitalName,
        @Size(max = 7) String accentColor,
        @Size(max = 7) String bgLight
) {}
