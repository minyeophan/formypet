package com.formypet.domain.policy.dto.response;
public record PolicyConsentStatusResponse(boolean enforcementEnabled, boolean acceptanceRequired,
        String termsVersion, String privacyVersion) {}
