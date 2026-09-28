package com.formypet.policy;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.formypet.common.exception.ApiException;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import java.io.IOException;
import java.time.Instant;
import java.util.*;

/** Published entries are append-only release artifacts, shared by web and app. */
@Component
public class PolicyCatalog {
    public record Document(String type, String version, String title, String body,
                           Instant publishedAt, Instant effectiveAt, String acceptanceRevision) {}
    public record Source(boolean published, List<Document> documents) {}
    public record Status(boolean published, boolean enforcementEnabled, List<Document> documents, Map<String,Document> currentDocuments) {}
    private final Source source;
    private final PolicyPublicationRegistry registry;
    public PolicyCatalog(ObjectMapper json, PolicyPublicationRegistry registry,
                         @Value("${app.policies.catalog:classpath:policies/catalog.json}") Resource resource,
                         @Value("${app.policies.enforcement-enabled:false}") boolean enforcement) throws IOException {
        try (var input = resource.getInputStream()) { source = json.readValue(input, Source.class); }
        this.registry = registry;
        Set<String> keys = new HashSet<>();
        if (source.documents() == null) throw new IllegalStateException("Policy documents are required");
        for (Document doc : source.documents()) {
            if (!Set.of("terms", "privacy").contains(doc.type()) || blank(doc.version())
                    || !doc.version().matches("[a-zA-Z0-9._-]{1,64}") || blank(doc.title()) || blank(doc.body())
                    || doc.publishedAt() == null || doc.effectiveAt() == null
                    || doc.effectiveAt().isBefore(doc.publishedAt())
                    || doc.publishedAt().getNano()%1000!=0 || doc.effectiveAt().getNano()%1000!=0
                    || doc.title().length()>255 || (doc.acceptanceRevision()!=null && doc.acceptanceRevision().length()>64)
                    || (doc.type().equals("terms") && blank(doc.acceptanceRevision()))
                    || !keys.add(doc.type() + ":" + doc.version())) {
                throw new IllegalStateException("Invalid policy catalog");
            }
        }
        if (enforcement && !source.published()) throw new IllegalStateException("Cannot activate an unpublished policy catalog");
        if(source.published()) registry.publish(source.documents(),enforcement);
    }
    public Status status() {
        List<Document> documents=registry.published();
        Instant now=registry.now();
        Map<String,Document> current=new HashMap<>();
        for(Document doc:documents) if(!doc.effectiveAt().isAfter(now)) current.put(doc.type(),doc);
        return new Status(!documents.isEmpty(),registry.enforced(),documents,Map.copyOf(current));
    }
    public boolean enforced() { return registry.enforced(); }
    public Document current(String type) {
        Document document = currentOrNull(type);
        if (document == null) throw error(HttpStatus.SERVICE_UNAVAILABLE, "POLICY_NOT_PUBLISHED", "정책 전문 게시 준비 중입니다.");
        return document;
    }
    private Document currentOrNull(String type) {
        return status().currentDocuments().get(type);
    }
    public Document version(String type, String version) {
        return status().documents().stream().filter(d -> d.type().equals(type) && d.version().equals(version))
                .findFirst().orElseThrow(() -> error(HttpStatus.NOT_FOUND, "POLICY_NOT_FOUND", "정책 전문을 찾을 수 없습니다."));
    }
    private static boolean blank(String value) { return value == null || value.isBlank(); }
    public static ApiException error(HttpStatus status, String code, String detail) {
        return new ApiException(status, "policy", "Policy", detail, code);
    }
}
