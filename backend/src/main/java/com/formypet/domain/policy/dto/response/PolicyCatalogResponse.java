package com.formypet.domain.policy.dto.response;
import java.util.List;
import java.util.Map;
public record PolicyCatalogResponse(boolean published, boolean enforcementEnabled,
        List<PolicyDocumentResponse> documents, Map<String,PolicyDocumentResponse> currentDocuments) {}
