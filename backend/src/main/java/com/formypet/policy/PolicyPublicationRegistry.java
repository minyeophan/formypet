package com.formypet.policy;

import com.formypet.auth.recovery.RecoveryCrypto;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.sql.init.dependency.DependsOnDatabaseInitialization;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;
import java.time.*;
import java.util.*;

@Component
@RequiredArgsConstructor
@DependsOnDatabaseInitialization
public class PolicyPublicationRegistry {
    private final JdbcTemplate jdbc;
    @Transactional
    public void publish(List<PolicyCatalog.Document> documents, boolean activate) {
        jdbc.queryForObject("SELECT id FROM policy_runtime WHERE id=1 FOR UPDATE",Integer.class);
        for(var doc:documents) {
            String hash=hash(doc);
            jdbc.update("""
                    INSERT IGNORE INTO policy_publications(document_type,document_version,title,body,published_at,effective_at,acceptance_revision,content_hash)
                    VALUES (?,?,?,?,?,?,?,?)
                    """,doc.type(),doc.version(),doc.title(),doc.body(),LocalDateTime.ofInstant(doc.publishedAt(),ZoneOffset.UTC),
                    LocalDateTime.ofInstant(doc.effectiveAt(),ZoneOffset.UTC),doc.acceptanceRevision(),hash);
            String stored=jdbc.queryForObject("SELECT content_hash FROM policy_publications WHERE document_type=? AND document_version=?",String.class,doc.type(),doc.version());
            if(!hash.equals(stored)) throw new IllegalStateException("A published policy version cannot be overwritten");
        }
        if(activate) {
            int available=jdbc.queryForObject("SELECT COUNT(DISTINCT document_type) FROM policy_publications WHERE document_type IN ('terms','privacy') AND published_at<=UTC_TIMESTAMP(6) AND effective_at<=UTC_TIMESTAMP(6)",Integer.class);
            if(available!=2) throw new IllegalStateException("Consent enforcement requires effective terms and privacy policy");
            jdbc.update("UPDATE policy_runtime SET enforcement_enabled=TRUE WHERE id=1");
        }
    }
    public boolean enforced() { return Boolean.TRUE.equals(jdbc.queryForObject("SELECT enforcement_enabled FROM policy_runtime WHERE id=1",Boolean.class)); }
    public Instant now() { return jdbc.queryForObject("SELECT UTC_TIMESTAMP(6)",LocalDateTime.class).toInstant(ZoneOffset.UTC); }
    public List<PolicyCatalog.Document> published() {
        return jdbc.query("SELECT * FROM policy_publications WHERE published_at<=UTC_TIMESTAMP(6) ORDER BY effective_at,published_at,document_version",
                (rs,row)->new PolicyCatalog.Document(rs.getString("document_type"),rs.getString("document_version"),rs.getString("title"),rs.getString("body"),
                        rs.getObject("published_at",LocalDateTime.class).toInstant(ZoneOffset.UTC),rs.getObject("effective_at",LocalDateTime.class).toInstant(ZoneOffset.UTC),rs.getString("acceptance_revision")));
    }
    private static String hash(PolicyCatalog.Document d) {
        return RecoveryCrypto.hash(String.join("\0",d.type(),d.version(),d.title(),d.body(),d.publishedAt().toString(),d.effectiveAt().toString(),Objects.toString(d.acceptanceRevision(),"")));
    }
}
