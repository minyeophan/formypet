package com.formypet.routine.dto;

import jakarta.validation.constraints.NotBlank;

public record RoutineCompletionRequest(@NotBlank String status) {
}
