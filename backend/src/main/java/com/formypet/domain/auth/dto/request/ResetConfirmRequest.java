package com.formypet.domain.auth.dto.request;

import com.formypet.domain.auth.validation.NewPassword;

public record ResetConfirmRequest(@jakarta.validation.constraints.NotNull @jakarta.validation.constraints.Pattern(regexp="[A-Za-z0-9_-]{43}") String resetToken, @com.formypet.domain.auth.validation.NewPassword String newPassword, @jakarta.validation.constraints.NotNull @jakarta.validation.constraints.Pattern(regexp="[A-Za-z0-9_-]{16,64}") String requestId) {}
