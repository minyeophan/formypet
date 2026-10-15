package com.formypet.domain.notification.dto.request;

import jakarta.validation.constraints.NotBlank;

public record DeviceTokenRequest(
        @NotBlank String token,
        @NotBlank String platform
) {}
