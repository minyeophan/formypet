package com.formypet.domain.auth.service.impl;

import com.formypet.domain.auth.security.RecoveryCrypto;
import com.formypet.domain.auth.config.RecoveryProperties;
import com.formypet.domain.auth.security.RecoveryRateLimiter;
import com.formypet.domain.auth.service.RecoveryService;
import com.formypet.domain.auth.service.RecoveryTransactions;
import com.formypet.domain.auth.dto.request.ResetVerifyRequest;
import com.formypet.domain.auth.dto.request.ResetConfirmRequest;
import com.formypet.domain.auth.dto.response.ResetChallengeResponse;
import com.formypet.domain.auth.dto.response.ResetVerifiedResponse;
import com.formypet.domain.auth.exception.RecoveryErrors;

import com.formypet.domain.auth.security.SessionGuard;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import java.util.Locale;

/** Admission control finishes before acquiring any recovery mutation connection. */
@Service
@RequiredArgsConstructor
@Transactional(propagation = Propagation.NEVER)
public class RecoveryServiceImpl implements RecoveryService {
    private final RecoveryTransactions recovery;
    private final RecoveryProperties properties;
    private final RecoveryRateLimiter limits;
    private final RecoveryCrypto crypto;
    private final SessionGuard sessions;

    public ResetChallengeResponse request(String rawEmail, String ip) {
        enabled();
        limits.consume("request-ip", ip, properties.getIpHourlyLimit(), 3600, 0);
        String email = rawEmail.trim();
        var found = sessions.find(email);
        String subject = crypto.digest("subject", found.map(u -> "user:" + u.id())
                .orElse("email:" + email.toLowerCase(Locale.ROOT)));
        limits.consume("request-subject", subject, properties.getEmailHourlyLimit(), 3600, 60);
        return recovery.request(subject, found.map(com.formypet.domain.auth.entity.SessionSnapshot::id).orElse(null));
    }

    public ResetVerifiedResponse verify(ResetVerifyRequest body, String ip) {
        enabled();
        limits.consume("verify-ip", ip, properties.getActionMinuteLimit(), 60, 0);
        return recovery.verify(body);
    }

    public void confirm(ResetConfirmRequest body, String ip) {
        enabled();
        limits.consume("confirm-ip", ip, properties.getActionMinuteLimit(), 60, 0);
        recovery.confirm(body);
    }

    private void enabled() {
        if (!properties.isEnabled())
            throw RecoveryErrors.error(503, "PASSWORD_RESET_UNAVAILABLE", "현재 비밀번호 복구를 이용할 수 없습니다.");
    }
}
