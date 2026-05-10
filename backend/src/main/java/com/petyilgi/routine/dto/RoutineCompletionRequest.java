package com.petyilgi.routine.dto;

import jakarta.validation.constraints.NotBlank;

public record RoutineCompletionRequest(@NotBlank String status) {
}
