package com.formypet.domain.auth.dto.request;

public record ResetVerifyRequest(@jakarta.validation.constraints.NotNull @jakarta.validation.constraints.Pattern(regexp="[A-Za-z0-9_-]{43}") String challengeId, @jakarta.validation.constraints.NotNull @jakarta.validation.constraints.Pattern(regexp="[0-9]{6}") String code, @jakarta.validation.constraints.NotNull @jakarta.validation.constraints.Pattern(regexp="[A-Za-z0-9_-]{16,64}") String requestId) {}
