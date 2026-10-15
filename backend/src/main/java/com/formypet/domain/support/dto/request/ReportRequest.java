package com.formypet.domain.support.dto.request;

import jakarta.validation.constraints.*;

public record ReportRequest(
        @NotBlank @Pattern(regexp = "SPAM|ABUSE|INAPPROPRIATE|PRIVACY|OTHER") String reason,
        @Size(max = 500) String detail,
        @NotBlank @Pattern(regexp = "[A-Za-z0-9_-]{1,64}") String requestId) {}
