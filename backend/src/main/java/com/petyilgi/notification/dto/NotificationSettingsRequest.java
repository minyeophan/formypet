package com.petyilgi.notification.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotNull;

@Schema(description = "User-wide scheduled notification setting")
public record NotificationSettingsRequest(
        @NotNull @Schema(description = "Whether scheduled routine and care reminders are enabled", defaultValue = "true")
        Boolean enabled
) {}
