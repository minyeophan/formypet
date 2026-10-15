package com.formypet.domain.policy.service.impl;
import com.formypet.domain.policy.dto.response.PolicyDocumentResponse;
import com.formypet.domain.policy.service.PolicyPublicationRegistry;

import com.formypet.auth.recovery.RecoveryCrypto;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.sql.init.dependency.DependsOnDatabaseInitialization;
import com.formypet.domain.policy.entity.PolicyPublication;
import com.formypet.domain.policy.entity.PolicyPublicationId;
import com.formypet.domain.policy.repository.PolicyPublicationRepository;
import com.formypet.domain.policy.repository.PolicyRuntimeRepository;
import com.formypet.domain.policy.repository.jdbc.PolicyDatabaseAccess;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;
import java.time.*;
import java.util.*;

@Component
@RequiredArgsConstructor
@DependsOnDatabaseInitialization
public class PolicyPublicationRegistryImpl implements PolicyPublicationRegistry {
    private final PolicyPublicationRepository publications;
    private final PolicyRuntimeRepository runtime;
    private final PolicyDatabaseAccess database;
    @Transactional
    public void publish(List<PolicyDocumentResponse> documents, boolean activate) {
        database.lockPublication();
        for(var doc:documents) {
            String hash=hash(doc);
            var existing = publications.findCurrentForUpdate(doc.type(), doc.version());
            if (existing.isPresent()) {
                existing.get().requireSameContent(hash);
            } else {
                publications.saveAndFlush(new PolicyPublication(new PolicyPublicationId(doc.type(), doc.version()),
                        doc.title(), doc.body(), LocalDateTime.ofInstant(doc.publishedAt(), ZoneOffset.UTC),
                        LocalDateTime.ofInstant(doc.effectiveAt(), ZoneOffset.UTC), doc.acceptanceRevision(), hash));
            }
        }
        if(activate) {
            int available=publications.effectiveTypeCount();
            if(available!=2) throw new IllegalStateException("Consent enforcement requires effective terms and privacy policy");
            runtime.enableEnforcement();
        }
    }
    public boolean enforced() { return runtime.enforced(); }
    public Instant now() { return database.now(); }
    public List<PolicyDocumentResponse> published() {
        return publications.findPublished().stream().map(p -> new PolicyDocumentResponse(
                p.getId().getDocumentType(), p.getId().getDocumentVersion(), p.getTitle(), p.getBody(),
                p.getPublishedAt().toInstant(ZoneOffset.UTC), p.getEffectiveAt().toInstant(ZoneOffset.UTC),
                p.getAcceptanceRevision())).toList();
    }
    private static String hash(PolicyDocumentResponse d) {
        return RecoveryCrypto.hash(String.join("\0",d.type(),d.version(),d.title(),d.body(),d.publishedAt().toString(),d.effectiveAt().toString(),Objects.toString(d.acceptanceRevision(),"")));
    }
}
