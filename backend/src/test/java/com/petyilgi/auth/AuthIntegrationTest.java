package com.petyilgi.auth;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.petyilgi.support.IntegrationTestSupport;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.transaction.annotation.Transactional;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@AutoConfigureMockMvc
@Transactional
class AuthIntegrationTest extends IntegrationTestSupport {

    @Autowired MockMvc mockMvc;
    @Autowired ObjectMapper objectMapper;

    private static final String REGISTER_URL = "/api/v1/auth/register";
    private static final String LOGIN_URL    = "/api/v1/auth/login";
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
}
