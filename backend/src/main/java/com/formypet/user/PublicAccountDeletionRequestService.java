package com.formypet.user;

import com.formypet.common.exception.ApiException;
import com.formypet.common.ratelimit.RequestRateLimiter;
import com.formypet.common.ratelimit.RequestRateLimitProperties;
import com.formypet.support.SupportMailProperties;
import com.formypet.support.SupportMailTransport;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.time.Instant;

@Service
@RequiredArgsConstructor
public class PublicAccountDeletionRequestService {
    private final SupportMailProperties settings;
    private final SupportMailTransport mail;
    private final RequestRateLimiter requestRateLimiter;
    private final RequestRateLimitProperties requestLimits;

    public record Receipt(String requestId, Instant receivedAt) {}

    public Receipt submit(PublicAccountDeletionRequest request, String clientAddress) {
        if (!settings.isEnabled()) {
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "account-deletion-request",
                    "Deletion request unavailable", "현재 탈퇴 요청 접수를 이용할 수 없습니다. 잠시 후 다시 시도해 주세요.",
                    "ACCOUNT_DELETION_REQUEST_UNAVAILABLE");
        }
        String contact = request.contactEmail().trim().toLowerCase(java.util.Locale.ROOT);
        requestRateLimiter.consume(java.util.List.of(
                new RequestRateLimiter.Bucket("deletion-email-cooldown", contact, 1,
                        requestLimits.getDeletionEmailCooldownSeconds())),
                java.util.List.of(new RequestRateLimiter.SlidingWindow("deletion-email-hour", contact,
                                requestLimits.getDeletionEmailCapacity(), requestLimits.getDeletionEmailWindowSeconds(), 1),
                        new RequestRateLimiter.SlidingWindow("deletion-client", clientAddress,
                                requestLimits.getDeletionClientCapacity(), requestLimits.getDeletionClientWindowSeconds(), 1),
                        new RequestRateLimiter.SlidingWindow("deletion-global", "all",
                                requestLimits.getDeletionGlobalCapacity(), requestLimits.getDeletionGlobalWindowSeconds(), 1)));
        String body = "회원 탈퇴 요청\n요청 번호: " + request.requestId()
                + "\n계정 확인 정보: " + request.accountIdentifier().trim()
                + "\n회신 이메일: " + request.contactEmail().trim()
                + "\n\n요청자 본인 여부를 확인한 뒤 회원 탈퇴를 처리해 주세요. 처리 완료 후 회신해 주세요.";
        try {
            mail.send("[포마펫] 회원 탈퇴 요청 " + request.requestId(), body, request.contactEmail().trim());
        } catch (Exception failure) {
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "account-deletion-request",
                    "Deletion request unavailable", "요청을 접수하지 못했어요. 잠시 후 다시 시도해 주세요.",
                    "ACCOUNT_DELETION_REQUEST_UNAVAILABLE");
        }
        return new Receipt(request.requestId(), Instant.now());
    }

}
