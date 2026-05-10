package com.petyilgi.pet.dto;

import com.petyilgi.pet.domain.Gender;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.time.LocalDate;

public record PetCreateRequest(
        @NotBlank @Size(max = 50) String name,
        @NotBlank @Size(max = 30) String species,
        @NotNull LocalDate birthDate,
        Gender gender,
        BigDecimal weight,
        @Size(max = 20) String animalRegistrationNumber,
        Boolean neutered,
        String diseases,
        String specialNotes
) {}
