package com.formypet.domain.auth.dto.request;

public record CancelSignupRequest(@jakarta.validation.constraints.NotBlank @jakarta.validation.constraints.Size(max=200) String signupToken) {}
