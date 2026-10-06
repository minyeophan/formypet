package com.formypet.user;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Set;

public final class KakaoUnlinkWebhookAuthorizer {
    private static final String AUTHORIZATION_PREFIX = "KakaoAK ";
    private static final Set<String> REFERRERS = Set.of(
            "ACCOUNT_DELETE", "FORCED_ACCOUNT_DELETE", "UNLINK_FROM_APPS",
            "UNLINK_FROM_ADMIN", "INCOMPLETE_SIGN_UP");

    private final String appId;
    private final String primaryAdminKey;

    public KakaoUnlinkWebhookAuthorizer(String appId, String primaryAdminKey) {
        this.appId = appId == null ? "" : appId.trim();
        this.primaryAdminKey = primaryAdminKey == null ? "" : primaryAdminKey.trim();
    }

    public boolean authorizes(String authorization, String requestedAppId, String providerUserId, String referrerType) {
        if (appId.isEmpty() || primaryAdminKey.isEmpty() || authorization == null
                || authorization.length() > 512 || requestedAppId == null
                || providerUserId == null || referrerType == null) return false;
        String suppliedKey = authorization.startsWith(AUTHORIZATION_PREFIX)
                ? authorization.substring(AUTHORIZATION_PREFIX.length()) : "";
        boolean keyMatches = MessageDigest.isEqual(
                primaryAdminKey.getBytes(StandardCharsets.UTF_8), suppliedKey.getBytes(StandardCharsets.UTF_8));
        return keyMatches
                && appId.equals(requestedAppId)
                && providerUserId.matches("[0-9]{1,100}")
                && REFERRERS.contains(referrerType);
    }
}
