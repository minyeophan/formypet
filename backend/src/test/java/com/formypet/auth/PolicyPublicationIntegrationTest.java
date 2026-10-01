package com.formypet.auth;

import com.formypet.policy.*;
import com.formypet.support.IntegrationTestSupport;
import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.support.TransactionTemplate;
import java.time.Instant;
import java.util.*;
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
    PolicyCatalog.Document doc(String type,String version,String revision,String year) {
        var date=Instant.parse(year+"-01-01T00:00:00Z");
        return new PolicyCatalog.Document(type,version,"TEST ONLY",type+" "+version,Instant.parse("2000-01-01T00:00:00Z"),date,revision);
    }
    @Test void versionsCannotBeOverwrittenAndRemainAvailableWhenOldReleaseIsDeployed() {
        var terms=doc("terms","v1","r1","2000");
        registry.publish(List.of(terms,doc("privacy","v1",null,"2000")),true);
        assertThatThrownBy(()->registry.publish(List.of(new PolicyCatalog.Document("terms","v1","changed","changed",terms.publishedAt(),terms.effectiveAt(),"r1")),false))
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
}
