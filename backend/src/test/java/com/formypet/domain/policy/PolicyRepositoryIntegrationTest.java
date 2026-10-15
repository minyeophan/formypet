package com.formypet.domain.policy;

import com.formypet.domain.policy.entity.PolicyPublication;
import com.formypet.domain.policy.entity.PolicyPublicationId;
import com.formypet.domain.policy.repository.PolicyConsentRepository;
import com.formypet.domain.policy.repository.PolicyPublicationRepository;
import com.formypet.domain.policy.repository.PolicyRuntimeRepository;
import com.formypet.support.IntegrationTestSupport;
import jakarta.persistence.EntityManager;
import java.time.LocalDateTime;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import static org.assertj.core.api.Assertions.*;

@Transactional
class PolicyRepositoryIntegrationTest extends IntegrationTestSupport {
    @Autowired PolicyPublicationRepository publications;
    @Autowired PolicyConsentRepository consents;
    @Autowired PolicyRuntimeRepository runtime;
    @Autowired JdbcTemplate jdbc;
    @Autowired EntityManager entities;

    @Test void publicationCompositeKeyAndMicrosecondsRoundTripInSeoul() {
        var time = LocalDateTime.parse("2026-01-02T03:04:05.123456");
        var id = new PolicyPublicationId("terms", "repository-" + UUID.randomUUID());
        var publication = new PolicyPublication(id, "테스트 약관", "TEST FIXTURE ONLY", time,
                time.plusDays(1), "revision-1", "a".repeat(64));
        publications.saveAndFlush(publication);
        assertThat(jdbc.queryForObject("SELECT published_at FROM policy_publications WHERE document_type=? AND document_version=?",
                LocalDateTime.class, id.getDocumentType(), id.getDocumentVersion())).isEqualTo(time);
        entities.clear();
        var loaded = publications.findById(id).orElseThrow();
        assertThat(loaded.getPublishedAt()).isEqualTo(time);
        assertThat(loaded.getEffectiveAt()).isEqualTo(time.plusDays(1));
        assertThat(loaded.getBody()).isEqualTo("TEST FIXTURE ONLY");
        assertThatCode(() -> loaded.requireSameContent("a".repeat(64))).doesNotThrowAnyException();
        assertThatThrownBy(() -> loaded.requireSameContent("b".repeat(64)))
                .isInstanceOf(IllegalStateException.class)
                .hasMessage("A published policy version cannot be overwritten");
    }

    @Test void duplicateConsentKeepsOriginalHashAndTimestampAndCountsDistinctActions() {
        long owner = user();
        assertThat(consents.recordIfAbsent(owner, "terms", "v1", "r1", "ACCEPTED", "a".repeat(64))).isEqualTo(1);
        var first = consents.findByUserIdOrderByRecordedAtAscIdAsc(owner).getFirst();
        assertThat(first.getRecordedAt()).isNotNull();
        assertThat(consents.recordIfAbsent(owner, "terms", "v1", "r1", "ACCEPTED", "b".repeat(64))).isZero();
        consents.recordIfAbsent(owner, "terms", "v2", "r1", "ACCEPTED", "b".repeat(64));
        assertThat(consents.acceptedActionCount(owner, "r1")).isEqualTo(1);
        consents.recordIfAbsent(owner, "terms", "v2", "r1", "AGE14_CONFIRMED", "b".repeat(64));
        assertThat(consents.acceptedActionCount(owner, "r1")).isEqualTo(2);
        assertThat(consents.acceptedActionCount(owner, "r2")).isZero();
        entities.clear();
        var retained = consents.findById(first.getId()).orElseThrow();
        assertThat(retained.getDocumentHash()).isEqualTo("a".repeat(64));
        assertThat(retained.getRecordedAt()).isEqualTo(first.getRecordedAt());
        assertThat(consents.findByUserIdOrderByRecordedAtAscIdAsc(owner + 1)).isEmpty();
    }

    @Test void legacyConsentUtcFieldsAndRuntimeActivationArePreserved() {
        long owner = user();
        var time = LocalDateTime.parse("2025-12-31T23:59:59.654321");
        jdbc.update("INSERT INTO policy_consents(user_id,document_type,document_version,action,document_hash,recorded_at) VALUES (?,'privacy','legacy','NOTICE_ACKNOWLEDGED',?,?)",
                owner, "c".repeat(64), time);
        var consent = consents.findByUserIdOrderByRecordedAtAscIdAsc(owner).getFirst();
        assertThat(consent.getRecordedAt()).isEqualTo(time);
        assertThat(consent.getAcceptanceRevision()).isNull();
        var state = runtime.findById(1).orElseThrow();
        state.enableEnforcement();
        runtime.flush();
        entities.clear();
        assertThat(runtime.findById(1).orElseThrow().isEnforcementEnabled()).isTrue();
    }

    @Test void publishedVisibilityAndEffectiveCountUseDatabaseTime() {
        jdbc.update("DELETE FROM policy_publications");
        var past = LocalDateTime.parse("2000-01-01T00:00:00");
        var future = LocalDateTime.parse("2099-01-01T00:00:00");
        publications.saveAndFlush(new PolicyPublication(new PolicyPublicationId("terms", "v1"),
                "test", "test", past, past, "r1", "a".repeat(64)));
        publications.saveAndFlush(new PolicyPublication(new PolicyPublicationId("privacy", "v1"),
                "test", "test", past, past, null, "b".repeat(64)));
        publications.saveAndFlush(new PolicyPublication(new PolicyPublicationId("terms", "future-effective"),
                "test", "test", past, future, "r2", "c".repeat(64)));
        publications.saveAndFlush(new PolicyPublication(new PolicyPublicationId("terms", "unpublished"),
                "test", "test", future, future, "r3", "d".repeat(64)));
        assertThat(publications.findPublished()).extracting(p -> p.getId().getDocumentVersion())
                .containsExactly("v1", "v1", "future-effective");
        assertThat(publications.effectiveTypeCount()).isEqualTo(2);
        assertThat(publications.findCurrentForUpdate("terms", "unpublished")).isPresent();
    }

    @Test void enforcementProjectionDoesNotReusePreviouslyLoadedRuntime() {
        jdbc.update("UPDATE policy_runtime SET enforcement_enabled=FALSE WHERE id=1");
        assertThat(runtime.findById(1).orElseThrow().isEnforcementEnabled()).isFalse();
        runtime.enableEnforcement();
        assertThat(runtime.enforced()).isTrue();
    }

    @Test void historyAndActionCountEachUseOneStatementWithoutUserEntityLoading() {
        long owner = user();
        consents.recordIfAbsent(owner, "terms", "v1", "r1", "ACCEPTED", "a".repeat(64));
        consents.recordIfAbsent(owner, "terms", "v1", "r1", "AGE14_CONFIRMED", "a".repeat(64));
        entities.clear();
        var stats = entities.getEntityManagerFactory().unwrap(org.hibernate.SessionFactory.class).getStatistics();
        boolean enabled = stats.isStatisticsEnabled();
        stats.setStatisticsEnabled(true);
        try {
            stats.clear();
            assertThat(consents.findByUserIdOrderByRecordedAtAscIdAsc(owner)).hasSize(2);
            assertThat(stats.getPrepareStatementCount()).isEqualTo(1);
            assertThat(stats.getEntityLoadCount()).isEqualTo(2);
            stats.clear();
            assertThat(consents.acceptedActionCount(owner, "r1")).isEqualTo(2);
            assertThat(stats.getPrepareStatementCount()).isEqualTo(1);
            assertThat(stats.getEntityLoadCount()).isZero();
        } finally { stats.setStatisticsEnabled(enabled); stats.clear(); }
    }

    private long user() {
        String email = UUID.randomUUID() + "@policy-repository.test";
        jdbc.update("INSERT INTO users(email,password_hash,nickname) VALUES (?,'unused','test')", email);
        return jdbc.queryForObject("SELECT id FROM users WHERE email=?", Long.class, email);
    }
}
