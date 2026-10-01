package com.formypet.user;

import com.formypet.common.exception.ApiException;
import com.formypet.support.SupportMailProperties;
import com.formypet.support.SupportMailTransport;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.concurrent.ConcurrentHashMap;

@Service
@RequiredArgsConstructor
public class PublicAccountDeletionRequestService {
    private final SupportMailProperties settings;
    private final SupportMailTransport mail;
    private final ConcurrentHashMap<String, Long> lastRequestByContact = new ConcurrentHashMap<>();

    public record Receipt(String requestId, OffsetDateTime receivedAt) {}

    public Receipt submit(PublicAccountDeletionRequest request) {
        if (!settings.isEnabled()) {
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "account-deletion-request",
                    "Deletion request unavailable", "현재 탈퇴 요청 접수를 이용할 수 없습니다. 잠시 후 다시 시도해 주세요.",
                    "ACCOUNT_DELETION_REQUEST_UNAVAILABLE");
        }
        long now = System.currentTimeMillis();
        String limiterKey = limiterKey(request.contactEmail());
        Long previous = lastRequestByContact.put(limiterKey, now);
        if (previous != null && now - previous < 30_000) {
            throw new ApiException(HttpStatus.TOO_MANY_REQUESTS, "account-deletion-request",
                    "Too many requests", "잠시 후 다시 요청해 주세요.", "ACCOUNT_DELETION_REQUEST_RATE_LIMITED");
        }
        lastRequestByContact.entrySet().removeIf(entry -> now - entry.getValue() > 3_600_000);
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
        return new Receipt(request.requestId(), OffsetDateTime.now(ZoneOffset.UTC));
    }

    private String limiterKey(String email) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256")
                    .digest(email.trim().toLowerCase(java.util.Locale.ROOT).getBytes(StandardCharsets.UTF_8));
            return java.util.HexFormat.of().formatHex(digest);
        } catch (NoSuchAlgorithmException impossible) {
            throw new IllegalStateException("SHA-256 unavailable", impossible);
        }
    }
}
