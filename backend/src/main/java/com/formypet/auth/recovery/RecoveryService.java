package com.formypet.auth.recovery;

import com.formypet.auth.SessionGuard;
import com.formypet.common.exception.ApiException;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import java.util.Locale;
import static com.formypet.auth.recovery.RecoveryController.*;

/** Admission control finishes before acquiring any recovery mutation connection. */
@Service
@RequiredArgsConstructor
@Transactional(propagation = Propagation.NEVER)
public class RecoveryService {
    private final RecoveryTransactions recovery;
    private final RecoveryProperties properties;
    private final RecoveryRateLimiter limits;
    private final RecoveryCrypto crypto;
    private final SessionGuard sessions;

    public Challenge request(String rawEmail, String ip) {
        enabled();
        limits.consume("request-ip", ip, properties.getIpHourlyLimit(), 3600, 0);
        String email = rawEmail.trim();
        var found = sessions.find(email);
        String subject = crypto.digest("subject", found.map(u -> "user:" + u.id())
                .orElse("email:" + email.toLowerCase(Locale.ROOT)));
        limits.consume("request-subject", subject, properties.getEmailHourlyLimit(), 3600, 60);
        return recovery.request(subject, found.map(SessionGuard.Snapshot::id).orElse(null));
    }

    public Verified verify(Verify body, String ip) {
        enabled();
        limits.consume("verify-ip", ip, properties.getActionMinuteLimit(), 60, 0);
        return recovery.verify(body);
    }

    public void confirm(Confirm body, String ip) {
        enabled();
        limits.consume("confirm-ip", ip, properties.getActionMinuteLimit(), 60, 0);
        recovery.confirm(body);
    }

    private void enabled() {
        if (!properties.isEnabled())
            throw error(503, "PASSWORD_RESET_UNAVAILABLE", "현재 비밀번호 복구를 이용할 수 없습니다.");
    }

    static ApiException error(int status, String code, String detail) {
        return RecoveryTransactions.error(status, code, detail);
    }
}
