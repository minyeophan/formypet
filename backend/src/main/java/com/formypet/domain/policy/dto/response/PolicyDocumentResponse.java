package com.formypet.domain.policy.dto.response;
import java.time.Instant;
public record PolicyDocumentResponse(String type, String version, String title, String body,
        Instant publishedAt, Instant effectiveAt, String acceptanceRevision) {}
