package com.formypet.notification.dto;

import io.swagger.v3.oas.annotations.media.Schema;

@Schema(description = "User-wide scheduled notification setting")
public record NotificationSettingsResponse(
        @Schema(description = "Whether scheduled routine and care reminders are enabled", defaultValue = "true")
        boolean enabled
) {}
