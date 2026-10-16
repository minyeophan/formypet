package com.formypet.domain.auth.dto.response;

public record ResetChallengeResponse(String challengeId, java.time.Instant expiresAt, java.time.Instant resendAvailableAt) {}
