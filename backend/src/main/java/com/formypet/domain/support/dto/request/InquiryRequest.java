package com.formypet.domain.support.dto.request;

import jakarta.validation.constraints.*;

public record InquiryRequest(
        @NotBlank @Pattern(regexp = "ACCOUNT|RECORD_ROUTINE|COMMUNITY|BUG|OTHER") String type,
        @NotBlank @Email @Size(max = 254) @Pattern(regexp = "[^\\r\\n]+") String replyEmail,
        @NotBlank @Size(max = 100) @Pattern(regexp = "[^\\r\\n]+") String title,
        @NotBlank @Size(max = 3000) String body,
        @NotBlank @Pattern(regexp = "[A-Za-z0-9_-]{1,64}") String requestId) {}
