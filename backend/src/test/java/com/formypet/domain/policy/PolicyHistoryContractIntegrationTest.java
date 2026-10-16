package com.formypet.domain.policy;
import com.formypet.domain.auth.security.JwtService;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.formypet.support.IntegrationTestSupport;
import java.time.LocalDateTime;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;
import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@AutoConfigureMockMvc
@Transactional
class PolicyHistoryContractIntegrationTest extends IntegrationTestSupport {
    @Autowired MockMvc mvc;
    @Autowired JdbcTemplate jdbc;
    @Autowired ObjectMapper json;
    @Autowired JwtService jwt;

    @Test void historyRetainsJdbcJsonShapeUtcTimestampAndStableTieOrder() throws Exception {
        String email = UUID.randomUUID() + "@policy-history.test";
        jdbc.update("INSERT INTO users(email,password_hash,nickname) VALUES (?,'unused','test')", email);
        long owner = jdbc.queryForObject("SELECT id FROM users WHERE email=?", Long.class, email);
        var time = LocalDateTime.parse("2026-01-01T23:59:59.123456");
        for (String action : new String[]{"AGE14_CONFIRMED", "ACCEPTED"}) {
            jdbc.update("INSERT INTO policy_consents(user_id,document_type,document_version,action,document_hash,recorded_at) VALUES (?,'terms','contract',?,?,?)",
                    owner, action, "a".repeat(64), time);
        }
        var expected = json.valueToTree(jdbc.queryForList("SELECT document_type,document_version,action,recorded_at FROM policy_consents WHERE user_id=? ORDER BY recorded_at,id", owner));
        var response = mvc.perform(get("/api/v1/users/me/policy-consents")
                        .header("Authorization", "Bearer " + jwt.generateAccessToken(owner, 0)))
                .andExpect(status().isOk()).andReturn();
        var actual = json.readTree(response.getResponse().getContentAsString()).path("data");
        assertThat(actual).isEqualTo(expected);
        assertThat(actual.get(0).path("action").asText()).isEqualTo("AGE14_CONFIRMED");
        assertThat(actual.get(0).size()).isEqualTo(4);
    }
}
