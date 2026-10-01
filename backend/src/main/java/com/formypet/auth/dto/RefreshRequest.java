package com.formypet.auth.dto;

import jakarta.validation.constraints.NotBlank;
import io.swagger.v3.oas.annotations.media.Schema;

public record RefreshRequest(@Schema(description = "발급받은 refresh token", format = "password", writeOnly = true) @NotBlank String refreshToken) {}
