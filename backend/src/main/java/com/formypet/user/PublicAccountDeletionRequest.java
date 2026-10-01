package com.formypet.user;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record PublicAccountDeletionRequest(
        @NotBlank @Email @Size(max = 254) @Pattern(regexp = "[^\\r\\n]+") String contactEmail,
        @NotBlank @Size(max = 254) @Pattern(regexp = "[^\\r\\n]+") String accountIdentifier,
        @NotBlank @Pattern(regexp = "[A-Za-z0-9_-]{1,64}") String requestId) {
}
