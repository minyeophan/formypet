package com.formypet.auth;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.formypet.support.IntegrationTestSupport;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import java.util.Map;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@AutoConfigureMockMvc
class PasswordRecoveryIntegrationTest extends IntegrationTestSupport {
    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;

    @Test void disabledRecoveryReturnsServiceUnavailableEvenWithStaleAuthorization() throws Exception {
        mvc.perform(post("/api/v1/auth/password-reset/request")
                .header("Authorization", "Bearer expired")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("email", "recovery@example.com"))))
                .andExpect(status().isServiceUnavailable())
                .andExpect(jsonPath("$.errorCode").value("PASSWORD_RESET_UNAVAILABLE"));
    }

    @Test void registrationRejectsPasswordOverBcryptByteLimit() throws Exception {
        mvc.perform(post("/api/v1/auth/register").contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("email", "long-recovery@example.com",
                        "password", "가".repeat(25), "nickname", "test"))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.fieldErrors.password").exists());
    }
}
