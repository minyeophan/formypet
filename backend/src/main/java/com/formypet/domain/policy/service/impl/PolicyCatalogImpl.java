package com.formypet.domain.policy.service.impl;
import com.formypet.domain.policy.config.PolicyCatalogLoader;
import com.formypet.domain.policy.dto.response.PolicyCatalogResponse;
import com.formypet.domain.policy.dto.response.PolicyDocumentResponse;
import com.formypet.domain.policy.service.PolicyCatalog;
import com.formypet.domain.policy.service.PolicyPublicationRegistry;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import java.time.Instant;
import java.util.*;

@Service
public class PolicyCatalogImpl implements PolicyCatalog {
    private final PolicyPublicationRegistry registry;
    public PolicyCatalogImpl(PolicyCatalogLoader loader, PolicyPublicationRegistry registry) {
        this.registry = registry;
        if (loader.source().published()) registry.publish(loader.source().documents(), loader.enforcement());
    }
    public PolicyCatalogResponse status() {
        List<PolicyDocumentResponse> documents=registry.published();
        Instant now=registry.now();
        Map<String,PolicyDocumentResponse> current=new HashMap<>();
        for(PolicyDocumentResponse doc:documents) if(!doc.effectiveAt().isAfter(now)) current.put(doc.type(),doc);
        return new PolicyCatalogResponse(!documents.isEmpty(),registry.enforced(),documents,Map.copyOf(current));
    }
    public boolean enforced() { return registry.enforced(); }
    public PolicyDocumentResponse current(String type) {
        PolicyDocumentResponse document = currentOrNull(type);
        if (document == null) throw PolicyCatalog.error(HttpStatus.SERVICE_UNAVAILABLE, "POLICY_NOT_PUBLISHED", "정책 전문 게시 준비 중입니다.");
        return document;
    }
    private PolicyDocumentResponse currentOrNull(String type) {
        return status().currentDocuments().get(type);
    }
    public PolicyDocumentResponse version(String type, String version) {
        return status().documents().stream().filter(d -> d.type().equals(type) && d.version().equals(version))
                .findFirst().orElseThrow(() -> PolicyCatalog.error(HttpStatus.NOT_FOUND, "POLICY_NOT_FOUND", "정책 전문을 찾을 수 없습니다."));
    }
}
