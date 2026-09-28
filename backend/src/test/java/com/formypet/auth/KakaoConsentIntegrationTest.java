package com.formypet.auth;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.formypet.auth.client.*;
import com.formypet.support.IntegrationTestSupport;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;
import java.util.*;
import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@AutoConfigureMockMvc
@TestPropertySource(properties={"app.policies.catalog=classpath:policy-test-catalog.json", "app.policies.enforcement-enabled=true"})
class KakaoConsentIntegrationTest extends IntegrationTestSupport {
    @org.junit.jupiter.api.AfterAll
    static void clearTestPublication(@Autowired JdbcTemplate db) {
        db.update("DELETE FROM policy_publications");
        db.update("UPDATE policy_runtime SET enforcement_enabled=FALSE WHERE id=1");
    }
    @Autowired MockMvc mvc; @Autowired ObjectMapper json; @Autowired JdbcTemplate jdbc;
    @MockitoBean KakaoUserClient kakao;
    @Autowired KakaoSignupIntents intents;

    @Test void oldClientIsRejectedAndAbandonedIntentExpiresIntoCleanup() throws Exception {
        String providerId=Long.toString(System.nanoTime()), sdk=UUID.randomUUID().toString();
        when(kakao.fetchUser(sdk)).thenReturn(new KakaoUserInfo(providerId,null,false,"test"));
        mvc.perform(post("/api/v1/auth/kakao").contentType("application/json")
                .content(json.writeValueAsString(Map.of("accessToken",sdk))))
                .andExpect(status().isUpgradeRequired()).andExpect(jsonPath("$.errorCode").value("APP_UPDATE_REQUIRED"));
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM oauth_accounts WHERE provider_user_id=?",Integer.class,providerId)).isZero();
        jdbc.update("UPDATE kakao_signup_intents SET expires_at=DATE_SUB(UTC_TIMESTAMP(6),INTERVAL 1 MINUTE) WHERE provider_user_id=?",providerId);
        intents.expire();
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM kakao_signup_intents WHERE provider_user_id=?",Integer.class,providerId)).isZero();
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM account_deletion_jobs WHERE provider_user_id=?",Integer.class,providerId)).isEqualTo(1);
    }

    @Test void staleVersionRollsBackAccountCreationAndExpiredIntentCannotSubmit() throws Exception {
        String providerId=Long.toString(System.nanoTime()), sdk=UUID.randomUUID().toString();
        when(kakao.fetchUser(sdk)).thenReturn(new KakaoUserInfo(providerId,null,false,"test"));
        var pending=mvc.perform(post("/api/v1/auth/kakao").header("X-Policy-Flow","1").contentType("application/json")
                .content(json.writeValueAsString(Map.of("accessToken",sdk)))).andExpect(status().isOk()).andReturn();
        String intent=json.readTree(pending.getResponse().getContentAsString()).path("data").path("signupToken").asText();
        var request=Map.of("accessToken",sdk,"signupToken",intent,"policyAcceptance",
                Map.of("termsVersion","old","termsAccepted",true,"age14Confirmed",true));
        mvc.perform(post("/api/v1/auth/kakao").header("X-Policy-Flow","1").contentType("application/json").content(json.writeValueAsString(request)))
                .andExpect(status().isConflict()).andExpect(jsonPath("$.errorCode").value("POLICY_VERSION_CHANGED"));
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM oauth_accounts WHERE provider_user_id=?",Integer.class,providerId)).isZero();
        jdbc.update("UPDATE kakao_signup_intents SET expires_at=DATE_SUB(UTC_TIMESTAMP(6),INTERVAL 1 MINUTE) WHERE provider_user_id=?",providerId);
        mvc.perform(post("/api/v1/auth/kakao").header("X-Policy-Flow","1").contentType("application/json").content(json.writeValueAsString(request)))
                .andExpect(status().isConflict()).andExpect(jsonPath("$.errorCode").value("KAKAO_SIGNUP_EXPIRED"));
    }
    @Test void newKakaoAccountIsNotCreatedUntilActualAcceptance() throws Exception {
        String providerId=Long.toString(System.nanoTime()), sdk=UUID.randomUUID().toString();
        when(kakao.fetchUser(sdk)).thenReturn(new KakaoUserInfo(providerId,null,false,"test"));
        var pending=mvc.perform(post("/api/v1/auth/kakao").header("X-Policy-Flow","1").contentType("application/json")
                .content(json.writeValueAsString(Map.of("accessToken",sdk))))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data.signupRequired").value(true)).andReturn();
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM oauth_accounts WHERE provider_user_id=?",Integer.class,providerId)).isZero();
        String intent=json.readTree(pending.getResponse().getContentAsString()).path("data").path("signupToken").asText();
        var accepted=Map.of("accessToken",sdk,"signupToken",intent,"policyAcceptance",
                Map.of("termsVersion","test-1","termsAccepted",true,"age14Confirmed",true));
        mvc.perform(post("/api/v1/auth/kakao").contentType("application/json").content(json.writeValueAsString(accepted)))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data.accessToken").isNotEmpty());
        long id=jdbc.queryForObject("SELECT user_id FROM oauth_accounts WHERE provider_user_id=?",Long.class,providerId);
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM policy_consents WHERE user_id=?",Integer.class,id)).isEqualTo(2);
        mvc.perform(post("/api/v1/auth/kakao/signup-cancellation").contentType("application/json")
                .content(json.writeValueAsString(Map.of("signupToken",intent)))).andExpect(status().isOk());
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM account_deletion_jobs WHERE provider_user_id=?",Integer.class,providerId)).isZero();
    }
    @Test void explicitCancellationQueuesUnlinkWithoutCreatingAnAccount() throws Exception {
        String providerId=Long.toString(System.nanoTime()), sdk=UUID.randomUUID().toString();
        when(kakao.fetchUser(sdk)).thenReturn(new KakaoUserInfo(providerId,null,false,"test"));
        var pending=mvc.perform(post("/api/v1/auth/kakao").header("X-Policy-Flow","1").contentType("application/json")
                .content(json.writeValueAsString(Map.of("accessToken",sdk))))
                .andExpect(status().isOk()).andReturn();
        String intent=json.readTree(pending.getResponse().getContentAsString()).path("data").path("signupToken").asText();
        mvc.perform(post("/api/v1/auth/kakao/signup-cancellation").contentType("application/json")
                .content(json.writeValueAsString(Map.of("signupToken",intent)))).andExpect(status().isOk());
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM oauth_accounts WHERE provider_user_id=?",Integer.class,providerId)).isZero();
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM account_deletion_jobs WHERE provider_user_id=?",Integer.class,providerId)).isEqualTo(1);
    }
}
