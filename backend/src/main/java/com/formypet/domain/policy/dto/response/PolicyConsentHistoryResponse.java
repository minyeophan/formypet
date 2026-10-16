package com.formypet.domain.policy.dto.response;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.formypet.domain.policy.entity.PolicyConsent;
import java.time.LocalDateTime;

/** Preserve the historical snake_case keys and JDBC DATETIME JSON representation. */
public record PolicyConsentHistoryResponse(
        @JsonProperty("document_type") String documentType,
        @JsonProperty("document_version") String documentVersion,
        String action,
        @JsonProperty("recorded_at") LocalDateTime recordedAt) {
    public static PolicyConsentHistoryResponse from(PolicyConsent consent) {
        return new PolicyConsentHistoryResponse(consent.getDocumentType(), consent.getDocumentVersion(),
                consent.getAction(), consent.getRecordedAt());
    }
}
