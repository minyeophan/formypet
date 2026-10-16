package com.formypet.domain.routine.dto.request;

import jakarta.validation.constraints.NotBlank;

public record RoutineCompletionRequest(@NotBlank String status) {
}
