package com.formypet.user;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class KakaoUnlinkWebhookAuthorizerTest {
    private final KakaoUnlinkWebhookAuthorizer authorizer =
            new KakaoUnlinkWebhookAuthorizer("1453687", "primary-admin-key");

    @Test
    void acceptsOnlyKakaoRequestsForThisAppAndAValidProviderUser() {
        assertThat(authorizer.authorizes("KakaoAK primary-admin-key", "1453687", "123456789", "UNLINK_FROM_APPS"))
                .isTrue();
    }

    @Test
    void rejectsWrongAdminKeyAppIdMalformedUserIdAndUnknownReferrer() {
        assertThat(authorizer.authorizes("KakaoAK wrong-key", "1453687", "123456789", "UNLINK_FROM_APPS")).isFalse();
        assertThat(authorizer.authorizes("KakaoAK primary-admin-key", "other-app", "123456789", "UNLINK_FROM_APPS")).isFalse();
        assertThat(authorizer.authorizes("KakaoAK primary-admin-key", "1453687", "1234/567", "UNLINK_FROM_APPS")).isFalse();
        assertThat(authorizer.authorizes("KakaoAK primary-admin-key", "1453687", "123456789", "UNTRUSTED")).isFalse();
    }

    @Test
    void refusesToAuthenticateWhenRequiredServerConfigurationIsMissing() {
        assertThat(new KakaoUnlinkWebhookAuthorizer("", "primary-admin-key")
                .authorizes("KakaoAK primary-admin-key", "1453687", "123456789", "UNLINK_FROM_APPS")).isFalse();
        assertThat(new KakaoUnlinkWebhookAuthorizer("1453687", " ")
                .authorizes("KakaoAK primary-admin-key", "1453687", "123456789", "UNLINK_FROM_APPS")).isFalse();
    }
}
