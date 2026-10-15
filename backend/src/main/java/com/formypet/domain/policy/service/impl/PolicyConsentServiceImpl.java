package com.formypet.domain.policy.service.impl;
import com.formypet.domain.policy.dto.response.PolicyConsentStatusResponse;
import com.formypet.domain.policy.dto.response.PolicyDocumentResponse;
import com.formypet.domain.policy.service.PolicyConsentService;
import com.formypet.domain.policy.service.PolicyCatalog;
import com.formypet.domain.policy.dto.request.PolicyAcceptance;

import com.formypet.auth.SessionGuard;
import com.formypet.auth.recovery.RecoveryCrypto;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import com.formypet.domain.policy.repository.PolicyConsentRepository;
import com.formypet.domain.policy.dto.response.PolicyConsentHistoryResponse;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.*;
import java.util.*;

@Service
@RequiredArgsConstructor
public class PolicyConsentServiceImpl implements PolicyConsentService {
    private final PolicyCatalog catalog;
    private final PolicyConsentRepository consents;
    private final SessionGuard sessions;

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
    private void insert(long userId, PolicyDocumentResponse doc, String action) {
        consents.recordIfAbsent(userId, doc.type(), doc.version(), doc.acceptanceRevision(), action,
                RecoveryCrypto.hash(doc.body()));
    }
    public PolicyConsentStatusResponse status(long userId) {
        if (!catalog.enforced()) return new PolicyConsentStatusResponse(false, false, null, null);
        var terms = catalog.current("terms");
        long accepted = consents.acceptedActionCount(userId, terms.acceptanceRevision());
        return new PolicyConsentStatusResponse(true, accepted < 2, terms.version(), catalog.current("privacy").version());
    }
    public void requireAccepted(long userId) {
        if (status(userId).acceptanceRequired()) throw PolicyCatalog.error(HttpStatus.FORBIDDEN,
                "POLICY_ACCEPTANCE_REQUIRED", "서비스 이용 전에 변경된 이용약관을 확인해 주세요.");
    }
    public List<PolicyConsentHistoryResponse> history(long userId) {
        return consents.findByUserIdOrderByRecordedAtAscIdAsc(userId).stream()
                .map(PolicyConsentHistoryResponse::from).toList();
    }
    @Transactional
    public PolicyConsentStatusResponse accept(long userId, PolicyAcceptance acceptance) {
        sessions.lockCurrent(userId);
        recordSignup(userId, acceptance);
        return status(userId);
    }
}
