package com.petyilgi.auth;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.petyilgi.auth.client.KakaoUserClient;
import com.petyilgi.auth.client.KakaoUserInfo;
import com.petyilgi.auth.repository.OAuthAccountRepository;
import com.petyilgi.support.IntegrationTestSupport;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@AutoConfigureMockMvc
class AuthIntegrationTest extends IntegrationTestSupport {

    @Autowired MockMvc mockMvc;
    @Autowired ObjectMapper objectMapper;
    @Autowired com.petyilgi.auth.repository.UserRepository userRepository;
    @Autowired OAuthAccountRepository oauthAccountRepository;

    @MockitoBean KakaoUserClient kakaoUserClient;

    private static final String REGISTER_URL = "/api/v1/auth/register";
    private static final String LOGIN_URL    = "/api/v1/auth/login";
    private static final String KAKAO_URL    = "/api/v1/auth/kakao";
    private static final String REFRESH_URL  = "/api/v1/auth/refresh";
    private static final String LOGOUT_URL   = "/api/v1/auth/logout";
    private static final String PROTECTED_URL = "/api/v1/pets";

    @BeforeEach
    void setUp(@Autowired com.petyilgi.auth.repository.UserRepository userRepository,
               @Autowired com.petyilgi.auth.repository.RefreshTokenRepository refreshTokenRepository) {
        refreshTokenRepository.deleteAll();
        userRepository.deleteAll();
    }

    @Test
    void registerSuccessReturnsTokens() throws Exception {
        var body = Map.of(
                "email",    "user@example.com",
                "password", "Password1!",
                "nickname", "testuser"
        );

        mockMvc.perform(post(REGISTER_URL)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(body)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.accessToken").isNotEmpty())
                .andExpect(jsonPath("$.data.refreshToken").isNotEmpty());
    }

    @Test
    void loginWithWrongPasswordReturns401() throws Exception {
        // 먼저 회원가입
        var registerBody = Map.of(
                "email",    "user2@example.com",
                "password", "Password1!",
                "nickname", "testuser2"
        );
        mockMvc.perform(post(REGISTER_URL)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(registerBody)))
                .andExpect(status().isCreated());

        // 틀린 비밀번호로 로그인
        var loginBody = Map.of(
                "email",    "user2@example.com",
                "password", "WrongPassword!"
        );
        mockMvc.perform(post(LOGIN_URL)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(loginBody)))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void refreshTokenRotation() throws Exception {
        // 회원가입 후 refreshToken 획득
        var body = Map.of(
                "email",    "user3@example.com",
                "password", "Password1!",
                "nickname", "testuser3"
        );
        MvcResult result = mockMvc.perform(post(REGISTER_URL)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(body)))
                .andExpect(status().isCreated())
                .andReturn();

        var responseMap = objectMapper.readValue(result.getResponse().getContentAsString(), Map.class);
        var data = (Map<?, ?>) responseMap.get("data");
        String refreshToken = (String) data.get("refreshToken");

        // refresh 요청 → 새 토큰 발급
        MvcResult refreshResult = mockMvc.perform(post(REFRESH_URL)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("refreshToken", refreshToken))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.accessToken").isNotEmpty())
                .andExpect(jsonPath("$.data.refreshToken").isNotEmpty())
                .andReturn();

        var refreshMap = objectMapper.readValue(refreshResult.getResponse().getContentAsString(), Map.class);
        var newData = (Map<?, ?>) refreshMap.get("data");
        String newRefreshToken = (String) newData.get("refreshToken");

        assertThat(newRefreshToken).isNotEqualTo(refreshToken); // 토큰 로테이션

        // 이전 refreshToken은 재사용 불가
        mockMvc.perform(post(REFRESH_URL)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("refreshToken", refreshToken))))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void logoutInvalidatesRefreshToken() throws Exception {
        var body = Map.of(
                "email",    "logout@example.com",
                "password", "Password1!",
                "nickname", "logoutuser"
        );
        MvcResult result = mockMvc.perform(post(REGISTER_URL)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(body)))
                .andExpect(status().isCreated())
                .andReturn();

        var responseMap = objectMapper.readValue(result.getResponse().getContentAsString(), Map.class);
        var data = (Map<?, ?>) responseMap.get("data");
        String refreshToken = (String) data.get("refreshToken");

        mockMvc.perform(post(LOGOUT_URL)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("refreshToken", refreshToken))))
                .andExpect(status().isNoContent());

        mockMvc.perform(post(REFRESH_URL)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("refreshToken", refreshToken))))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void logoutUnknownRefreshTokenReturnsNoContent() throws Exception {
        mockMvc.perform(post(LOGOUT_URL)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("refreshToken", "missing-refresh-token"))))
                .andExpect(status().isNoContent());
    }

    @Test
    void accessProtectedEndpointWithoutTokenReturns401() throws Exception {
        mockMvc.perform(get(PROTECTED_URL))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void firstKakaoLoginIssuesTokensAndCreatesOAuthUserAndLink() throws Exception {
        when(kakaoUserClient.fetchUser("kakao-token"))
                .thenReturn(new KakaoUserInfo("1001", "kakao@example.com", true, "kakao-user"));

        mockMvc.perform(post(KAKAO_URL)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("accessToken", "kakao-token"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.accessToken").isNotEmpty())
                .andExpect(jsonPath("$.data.refreshToken").isNotEmpty());

        var user = userRepository.findByEmail("kakao@example.com").orElseThrow();
        assertThat(user.getRegistrationSource()).isEqualTo("KAKAO");
        assertThat(oauthAccountRepository.findByProviderAndProviderUserId("KAKAO", "1001"))
                .isPresent()
                .get()
                .extracting(account -> account.getUser().getId())
                .isEqualTo(user.getId());
    }

    @Test
    void kakaoReloginDoesNotCreateDuplicateUser() throws Exception {
        when(kakaoUserClient.fetchUser(anyString()))
                .thenReturn(new KakaoUserInfo("1002", "relogin@example.com", true, "first"))
                .thenReturn(new KakaoUserInfo("1002", "relogin@example.com", true, "second"));

        mockMvc.perform(post(KAKAO_URL)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("accessToken", "first-token"))))
                .andExpect(status().isOk());
        long userCountAfterFirstLogin = userRepository.count();

        mockMvc.perform(post(KAKAO_URL)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("accessToken", "second-token"))))
                .andExpect(status().isOk());

        assertThat(userRepository.count()).isEqualTo(userCountAfterFirstLogin);
        assertThat(oauthAccountRepository.findByProviderAndProviderUserId("KAKAO", "1002")).isPresent();
    }

    @Test
    void kakaoLoginDoesNotAutoLinkExistingLocalUserWithSameEmail() throws Exception {
        mockMvc.perform(post(REGISTER_URL)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "email", "same@example.com",
                                "password", "Password1!",
                                "nickname", "local"))))
                .andExpect(status().isCreated());

        when(kakaoUserClient.fetchUser("kakao-token"))
                .thenReturn(new KakaoUserInfo("1003", "same@example.com", true, "kakao"));

        mockMvc.perform(post(KAKAO_URL)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("accessToken", "kakao-token"))))
                .andExpect(status().isOk());

        assertThat(userRepository.count()).isEqualTo(2);
        assertThat(userRepository.findByEmail("same@example.com")).isPresent();
        assertThat(userRepository.findByEmail("kakao_1003@oauth.kakao.local")).isPresent();
    }

    @Test
    void kakaoLoginUsesInternalEmailWhenKakaoEmailIsMissingOrUnverified() throws Exception {
        when(kakaoUserClient.fetchUser("kakao-token"))
                .thenReturn(new KakaoUserInfo("1004", null, false, null));

        mockMvc.perform(post(KAKAO_URL)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("accessToken", "kakao-token"))))
                .andExpect(status().isOk());

        var user = userRepository.findByEmail("kakao_1004@oauth.kakao.local").orElseThrow();
        assertThat(user.getRegistrationSource()).isEqualTo("KAKAO");
    }

    @Test
    void oauthUserCannotLoginWithPassword() throws Exception {
        when(kakaoUserClient.fetchUser("kakao-token"))
                .thenReturn(new KakaoUserInfo("1005", "oauth-login@example.com", true, "oauth"));

        mockMvc.perform(post(KAKAO_URL)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("accessToken", "kakao-token"))))
                .andExpect(status().isOk());

        mockMvc.perform(post(LOGIN_URL)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "email", "oauth-login@example.com",
                                "password", "anything"))))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void rejectedKakaoTokenReturnsUnauthorizedNotInternalServerError() throws Exception {
        when(kakaoUserClient.fetchUser("expired-token"))
                .thenThrow(new org.springframework.security.authentication.BadCredentialsException("Invalid Kakao token"));

        mockMvc.perform(post(KAKAO_URL)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("accessToken", "expired-token"))))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void registerWithInternalOAuthEmailReturns400() throws Exception {
        mockMvc.perform(post(REGISTER_URL)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "email",    "kakao_9999@oauth.kakao.local",
                                "password", "Password1!",
                                "nickname", "testuser"))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.fieldErrors.email").value("사용할 수 없는 이메일 형식입니다."));
    }
}
