package com.petyilgi.pet.dto;

import com.petyilgi.pet.domain.Gender;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.time.LocalDate;

public record PetUpdateRequest(
        @NotBlank @Size(max = 50) String name,
        @Size(max = 30) String species,
        LocalDate birthDate,
        Gender gender,
        BigDecimal weight,
        @Size(max = 20) String animalRegistrationNumber,
        Boolean neutered,
        String diseases,
        String specialNotes
) {}
