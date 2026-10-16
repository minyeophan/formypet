package com.formypet.domain.policy.config;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.formypet.domain.policy.dto.response.PolicyDocumentResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.Resource;
import org.springframework.stereotype.Component;
import java.io.IOException;
import java.util.*;

/** Reads and validates the release artifact; database publication is a separate transaction. */
@Component
public class PolicyCatalogLoader {
    public record Source(boolean published, List<PolicyDocumentResponse> documents) {}
    private final Source source;
    private final boolean enforcement;
    public PolicyCatalogLoader(ObjectMapper json,
            @Value("${app.policies.catalog:classpath:policies/catalog.json}") Resource resource,
            @Value("${app.policies.enforcement-enabled:false}") boolean enforcement) throws IOException {
        try (var input = resource.getInputStream()) { source = json.readValue(input, Source.class); }
        this.enforcement = enforcement;
        Set<String> keys = new HashSet<>();
        if (source.documents() == null) throw new IllegalStateException("Policy documents are required");
        for (PolicyDocumentResponse doc : source.documents()) {
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
    }
    public Source source() { return source; }
    public boolean enforcement() { return enforcement; }
    private static boolean blank(String value) { return value == null || value.isBlank(); }
}
