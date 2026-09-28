package com.formypet.auth;

import com.formypet.support.IntegrationTestSupport;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.test.context.TestPropertySource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;
import java.util.*;
import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@AutoConfigureMockMvc
@TestPropertySource(properties={"app.policies.catalog=classpath:policy-test-catalog.json", "app.policies.enforcement-enabled=true"})
class PolicyConsentIntegrationTest extends IntegrationTestSupport {
    @org.junit.jupiter.api.AfterAll
    static void clearTestPublication(@Autowired JdbcTemplate db) {
        db.update("DELETE FROM policy_publications");
        db.update("UPDATE policy_runtime SET enforcement_enabled=FALSE WHERE id=1");
    }
    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;
    @Autowired JdbcTemplate jdbc;
    @Autowired JwtService jwt;
    Map<String,Object> acceptance(String version) {
        return Map.of("termsVersion",version,"termsAccepted",true,"age14Confirmed",true);
    }
    Map<String,Object> registration(String email) {
        return new HashMap<>(Map.of("email",email,"password","Password1!","nickname","tester"));
    }
    @Test void missingAndStaleAcceptanceCannotCreateAccounts() throws Exception {
        String email=UUID.randomUUID()+"@policy.test";
        var body=registration(email);
        mvc.perform(post("/api/v1/auth/register").contentType("application/json").content(json.writeValueAsString(body)))
                .andExpect(status().isBadRequest()).andExpect(jsonPath("$.errorCode").value("POLICY_ACCEPTANCE_REQUIRED"));
        body.put("policyAcceptance",acceptance("old"));
        mvc.perform(post("/api/v1/auth/register").contentType("application/json").content(json.writeValueAsString(body)))
                .andExpect(status().isConflict()).andExpect(jsonPath("$.errorCode").value("POLICY_VERSION_CHANGED"));
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM users WHERE email=?",Integer.class,email)).isZero();
    }
    @Test void signupStoresActualActionsAndAccountDeletionRemovesThem() throws Exception {
        String email=UUID.randomUUID()+"@policy.test";
        var body=registration(email);body.put("policyAcceptance",acceptance("test-1"));
        var response=mvc.perform(post("/api/v1/auth/register").contentType("application/json").content(json.writeValueAsString(body)))
                .andExpect(status().isCreated()).andReturn();
        String token=json.readTree(response.getResponse().getContentAsString()).path("data").path("accessToken").asText();
        long id=jdbc.queryForObject("SELECT id FROM users WHERE email=?",Long.class,email);
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM policy_consents WHERE user_id=?",Integer.class,id)).isEqualTo(2);
        mvc.perform(get("/api/v1/users/me/policy-status").header("Authorization","Bearer "+token))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data.acceptanceRequired").value(false));
        mvc.perform(delete("/api/v1/users/me").header("Authorization","Bearer "+token).contentType("application/json").content("{\"password\":\"Password1!\"}"))
                .andExpect(status().isAccepted());
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM policy_consents WHERE user_id=?",Integer.class,id)).isZero();
    }
    @Test void existingAccountMustAcceptButCanInspectPoliciesAndDeleteAccount() throws Exception {
        String email=UUID.randomUUID()+"@existing-policy.test";
        jdbc.update("INSERT INTO users(email,password_hash,nickname) VALUES (?,'unused','existing')",email);
        long id=jdbc.queryForObject("SELECT id FROM users WHERE email=?",Long.class,email);
        String token=jwt.generateAccessToken(id,0);
        mvc.perform(get("/api/v1/pets").header("Authorization","Bearer "+token))
                .andExpect(status().isForbidden()).andExpect(jsonPath("$.errorCode").value("POLICY_ACCEPTANCE_REQUIRED"));
        mvc.perform(get("/api/v1/users/me").header("Authorization","Bearer "+token)).andExpect(status().isOk());
        mvc.perform(get("/api/v1/users/me/policy-consents").header("Authorization","Bearer "+token))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data").isEmpty());
        for(int i=0;i<2;i++) mvc.perform(post("/api/v1/users/me/policy-consents").header("Authorization","Bearer "+token)
                .contentType("application/json").content(json.writeValueAsString(acceptance("test-1"))))
                .andExpect(status().isOk());
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM policy_consents WHERE user_id=?",Integer.class,id)).isEqualTo(2);
        mvc.perform(get("/api/v1/pets").header("Authorization","Bearer "+token)).andExpect(status().isOk());
    }
}
