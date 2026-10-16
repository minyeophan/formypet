package com.formypet.domain.auth.dto.response;

public record ResetVerifiedResponse(String resetToken, java.time.Instant expiresAt) {}
