package com.formypet.domain.policy;
import com.formypet.domain.policy.dto.response.PolicyDocumentResponse;
import com.formypet.domain.policy.service.PolicyPublicationRegistry;
import com.formypet.domain.policy.service.PolicyConsentService;
import com.formypet.domain.policy.service.PolicyCatalog;

import com.formypet.domain.policy.dto.request.PolicyAcceptance;
import com.formypet.support.IntegrationTestSupport;
import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.support.TransactionTemplate;
import java.time.Instant;
import java.util.*;
import java.util.concurrent.*;
import static org.assertj.core.api.Assertions.*;

class PolicyPublicationIntegrationTest extends IntegrationTestSupport {
    @Autowired PolicyPublicationRegistry registry;
    @Autowired PolicyCatalog catalog;
    @Autowired PolicyConsentService consents;
    @Autowired JdbcTemplate jdbc;
    @Autowired TransactionTemplate transactions;
    @BeforeEach @AfterEach void clearPublication() {
        jdbc.update("DELETE FROM policy_publications");
        jdbc.update("UPDATE policy_runtime SET enforcement_enabled=FALSE WHERE id=1");
    }
    PolicyDocumentResponse doc(String type,String version,String revision,String year) {
        var date=Instant.parse(year+"-01-01T00:00:00Z");
        return new PolicyDocumentResponse(type,version,"TEST ONLY",type+" "+version,Instant.parse("2000-01-01T00:00:00Z"),date,revision);
    }
    @Test void versionsCannotBeOverwrittenAndRemainAvailableWhenOldReleaseIsDeployed() {
        var terms=doc("terms","v1","r1","2000");
        registry.publish(List.of(terms,doc("privacy","v1",null,"2000")),true);
        assertThatThrownBy(()->registry.publish(List.of(new PolicyDocumentResponse("terms","v1","changed","changed",terms.publishedAt(),terms.effectiveAt(),"r1")),false))
                .isInstanceOf(IllegalStateException.class);
        registry.publish(List.of(doc("terms","v2","r1","2001")),false);
        registry.publish(List.of(),false);
        assertThat(catalog.version("terms","v1").body()).isEqualTo(terms.body());
        assertThat(catalog.current("terms").version()).isEqualTo("v2");
        assertThat(catalog.enforced()).isTrue();
    }
    @Test void onlyNewTermsAcceptanceRevisionRequiresReacceptance() {
        registry.publish(List.of(doc("terms","v1","r1","2000"),doc("privacy","v1",null,"2000")),true);
        String email=UUID.randomUUID()+"@publication.test";
        jdbc.update("INSERT INTO users(email,password_hash,nickname) VALUES (?,'unused','tester')",email);
        long id=jdbc.queryForObject("SELECT id FROM users WHERE email=?",Long.class,email);
        transactions.execute(status->{consents.recordSignup(id,new PolicyAcceptance("v1",true,true,null,false));return null;});
        registry.publish(List.of(doc("privacy","v2",null,"2001"),doc("terms","v2","r1","2001")),false);
        assertThat(consents.status(id).acceptanceRequired()).isFalse();
        registry.publish(List.of(doc("terms","v3","r2","2002")),false);
        assertThat(consents.status(id).acceptanceRequired()).isTrue();
        registry.publish(List.of(doc("terms","future","r3","2099")),false);
        assertThat(catalog.current("terms").version()).isEqualTo("v3");
        assertThat(catalog.version("terms","future").version()).isEqualTo("future");
    }

    @Test void conflictingVersionRollsBackEarlierInsertsInTheSameBatch() {
        var original = doc("terms", "v1", "r1", "2000");
        registry.publish(List.of(original), false);
        var conflict = new PolicyDocumentResponse("terms", "v1", "changed", "changed",
                original.publishedAt(), original.effectiveAt(), "r1");
        assertThatThrownBy(() -> registry.publish(List.of(doc("privacy", "v1", null, "2000"), conflict), true))
                .isInstanceOf(IllegalStateException.class);
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM policy_publications", Integer.class)).isEqualTo(1);
        assertThat(catalog.version("terms", "v1").body()).isEqualTo(original.body());
        assertThat(registry.enforced()).isFalse();
    }

    @Test void activationWithoutBothEffectiveDocumentsRollsBackTheBatch() {
        assertThatThrownBy(() -> registry.publish(List.of(doc("terms", "v1", "r1", "2000")), true))
                .isInstanceOf(IllegalStateException.class)
                .hasMessage("Consent enforcement requires effective terms and privacy policy");
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM policy_publications", Integer.class)).isZero();
        assertThat(registry.enforced()).isFalse();
    }

    @Test void publicationUsesCurrentReadEvenWhenCallerHasAnOlderSnapshot() throws Exception {
        var snapshotReady = new CountDownLatch(1);
        var committed = new CountDownLatch(1);
        var terms = doc("terms", "concurrent", "r1", "2000");
        try (var pool = Executors.newSingleThreadExecutor()) {
            Future<?> waiting = pool.submit(() -> transactions.executeWithoutResult(status -> {
                jdbc.queryForObject("SELECT COUNT(*) FROM policy_publications", Integer.class);
                snapshotReady.countDown();
                await(committed);
                registry.publish(List.of(terms), false);
            }));
            assertThat(snapshotReady.await(10, TimeUnit.SECONDS)).isTrue();
            try { registry.publish(List.of(terms), false); }
            finally { committed.countDown(); }
            waiting.get(15, TimeUnit.SECONDS);
        }
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM policy_publications", Integer.class)).isEqualTo(1);
    }

    @Test void concurrentDifferentContentForOneVersionHasOnlyOneWinner() throws Exception {
        var first = doc("terms", "race", "r1", "2000");
        var other = new PolicyDocumentResponse("terms", "race", "other", "other",
                first.publishedAt(), first.effectiveAt(), "r1");
        var start = new CountDownLatch(1);
        try (var pool = Executors.newFixedThreadPool(2)) {
            var one = pool.submit(() -> publishAfter(start, first));
            var two = pool.submit(() -> publishAfter(start, other));
            start.countDown();
            assertThat(List.of(one.get(15, TimeUnit.SECONDS), two.get(15, TimeUnit.SECONDS)))
                    .containsExactlyInAnyOrder(true, false);
        }
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM policy_publications", Integer.class)).isEqualTo(1);
        assertThat(catalog.version("terms", "race").body()).isIn(first.body(), other.body());
    }

    @Test void signupActionsRequireAndRollBackWithTheCallingTransaction() {
        registry.publish(List.of(doc("terms", "v1", "r1", "2000"), doc("privacy", "v1", null, "2000")), true);
        String email = UUID.randomUUID() + "@rollback-policy.test";
        jdbc.update("INSERT INTO users(email,password_hash,nickname) VALUES (?,'unused','test')", email);
        long id = jdbc.queryForObject("SELECT id FROM users WHERE email=?", Long.class, email);
        var acceptance = new PolicyAcceptance("v1", true, true, "v1", true);
        assertThatThrownBy(() -> consents.recordSignup(id, acceptance))
                .isInstanceOf(org.springframework.transaction.IllegalTransactionStateException.class);
        transactions.executeWithoutResult(status -> {
            consents.recordSignup(id, acceptance);
            assertThat(consents.history(id)).hasSize(3);
            status.setRollbackOnly();
        });
        assertThat(consents.history(id)).isEmpty();
        assertThat(consents.status(id).acceptanceRequired()).isTrue();
    }

    private boolean publishAfter(CountDownLatch start, PolicyDocumentResponse document) {
        await(start);
        try { registry.publish(List.of(document), false); return true; }
        catch (IllegalStateException expected) {
            assertThat(expected).hasMessage("A published policy version cannot be overwritten");
            return false;
        }
    }

    private static void await(CountDownLatch latch) {
        try { assertThat(latch.await(10, TimeUnit.SECONDS)).isTrue(); }
        catch (InterruptedException e) { Thread.currentThread().interrupt(); throw new AssertionError(e); }
    }
}
