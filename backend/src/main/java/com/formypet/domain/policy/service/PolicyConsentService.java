package com.formypet.domain.policy.service;
import com.formypet.domain.policy.dto.request.PolicyAcceptance;
import com.formypet.domain.policy.dto.response.PolicyConsentHistoryResponse;
import com.formypet.domain.policy.dto.response.PolicyConsentStatusResponse;
import java.util.List;
public interface PolicyConsentService {
    void validate(PolicyAcceptance acceptance);
    void recordSignup(long userId, PolicyAcceptance acceptance);
    PolicyConsentStatusResponse status(long userId);
    void requireAccepted(long userId);
    List<PolicyConsentHistoryResponse> history(long userId);
    PolicyConsentStatusResponse accept(long userId, PolicyAcceptance acceptance);
}
