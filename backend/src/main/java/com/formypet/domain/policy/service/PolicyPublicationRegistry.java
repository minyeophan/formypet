package com.formypet.domain.policy.service;
import com.formypet.domain.policy.dto.response.PolicyDocumentResponse;
import java.time.Instant;
import java.util.List;
public interface PolicyPublicationRegistry {
    void publish(List<PolicyDocumentResponse> documents, boolean activate);
    boolean enforced();
    Instant now();
    List<PolicyDocumentResponse> published();
}
