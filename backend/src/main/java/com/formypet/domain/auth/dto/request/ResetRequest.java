package com.formypet.domain.auth.dto.request;

public record ResetRequest(@jakarta.validation.constraints.NotBlank @jakarta.validation.constraints.Email @jakarta.validation.constraints.Size(max=254) String email) {}
