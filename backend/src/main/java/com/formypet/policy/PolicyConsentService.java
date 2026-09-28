package com.formypet.policy;

import com.formypet.auth.SessionGuard;
import com.formypet.auth.recovery.RecoveryCrypto;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.*;
import java.util.*;

@Service
@RequiredArgsConstructor
public class PolicyConsentService {
    private final PolicyCatalog catalog;
    private final JdbcTemplate jdbc;
    private final SessionGuard sessions;
    public record Status(boolean enforcementEnabled, boolean acceptanceRequired, String termsVersion,
                         String privacyVersion) {}

    public void validate(PolicyAcceptance acceptance) {
        if (!catalog.enforced() && acceptance == null) return;
        if (acceptance == null || !acceptance.termsAccepted() || !acceptance.age14Confirmed()) {
            throw PolicyCatalog.error(HttpStatus.BAD_REQUEST, "POLICY_ACCEPTANCE_REQUIRED", "이용약관 동의와 만 14세 이상 확인이 필요합니다.");
        }
        var terms = catalog.current("terms");
        if (!terms.version().equals(acceptance.termsVersion())) changed();
        if (acceptance.privacyNoticeAcknowledged()
                && !catalog.current("privacy").version().equals(acceptance.privacyNoticeVersion())) changed();
    }
    private static void changed() {
        throw PolicyCatalog.error(HttpStatus.CONFLICT, "POLICY_VERSION_CHANGED", "정책이 변경됐습니다. 최신 전문을 확인해 주세요.");
    }
    @Transactional(propagation = Propagation.MANDATORY)
    public void recordSignup(long userId, PolicyAcceptance acceptance) {
        validate(acceptance);
        if (acceptance == null) return;
        var terms = catalog.version("terms",acceptance.termsVersion());
        insert(userId, terms, "ACCEPTED");
        insert(userId, terms, "AGE14_CONFIRMED");
        if (acceptance.privacyNoticeAcknowledged()) insert(userId, catalog.version("privacy",acceptance.privacyNoticeVersion()), "NOTICE_ACKNOWLEDGED");
    }
    private void insert(long userId, PolicyCatalog.Document doc, String action) {
        jdbc.update("""
                INSERT IGNORE INTO policy_consents(user_id,document_type,document_version,acceptance_revision,action,document_hash)
                VALUES (?,?,?,?,?,?)
                """, userId, doc.type(), doc.version(), doc.acceptanceRevision(), action, RecoveryCrypto.hash(doc.body()));
    }
    public Status status(long userId) {
        if (!catalog.enforced()) return new Status(false, false, null, null);
        var terms = catalog.current("terms");
        int accepted = jdbc.queryForObject("""
                SELECT COUNT(DISTINCT action) FROM policy_consents
                WHERE user_id=? AND document_type='terms' AND acceptance_revision=?
                AND action IN ('ACCEPTED','AGE14_CONFIRMED')
                """, Integer.class, userId, terms.acceptanceRevision());
        return new Status(true, accepted < 2, terms.version(), catalog.current("privacy").version());
    }
    public void requireAccepted(long userId) {
        if (status(userId).acceptanceRequired()) throw PolicyCatalog.error(HttpStatus.FORBIDDEN,
                "POLICY_ACCEPTANCE_REQUIRED", "서비스 이용 전에 변경된 이용약관을 확인해 주세요.");
    }
    public List<Map<String,Object>> history(long userId) {
        return jdbc.queryForList("""
                SELECT document_type,document_version,action,recorded_at FROM policy_consents
                WHERE user_id=? ORDER BY recorded_at,id
                """, userId);
    }
    @Transactional
    public Status accept(long userId, PolicyAcceptance acceptance) {
        sessions.lockCurrent(userId);
        recordSignup(userId, acceptance);
        return status(userId);
    }
}
