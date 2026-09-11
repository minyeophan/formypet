package com.formypet.community;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.formypet.support.IntegrationTestSupport;
import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import java.util.Map;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@AutoConfigureMockMvc
@Transactional
@TestPropertySource(properties = {
        "app.firebase.credentials-path=build/no-firebase-for-news-tests.json",
        "app.notification.scheduler-enabled=false"
})
class CommunityNewsPermissionIntegrationTest extends IntegrationTestSupport {
    @Autowired MockMvc mvc;
    @Autowired ObjectMapper mapper;
    @Autowired JdbcTemplate jdbc;
    @Autowired EntityManager entities;

    @Test
    void ordinaryUserCannotCreateNewsEvenWithForgedRole() throws Exception {
        String token = register("news-reader@example.test");
        mvc.perform(multipart("/api/v1/posts")
                        .file(new MockMultipartFile("payload", "", "application/json",
                                mapper.writeValueAsBytes(Map.of("title", "news", "content", "body",
                                        "category", " news ", "role", "ADMIN"))))
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isForbidden());
    }

    @Test
    void ordinaryUserCannotMoveOwnPostIntoNews() throws Exception {
        String token = register("news-retag@example.test");
        long id = create(token, "FREE");
        mvc.perform(put("/api/v1/posts/{id}", id)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(mapper.writeValueAsBytes(Map.of("title", "changed", "content", "body", "category", "NEWS"))))
                .andExpect(status().isForbidden());
        mvc.perform(get("/api/v1/posts/{id}", id).header("Authorization", "Bearer " + token))
                .andExpect(jsonPath("$.data.category").value("FREE"));
    }

    @Test
    void adminCanPublishAndEditNewsWhileOrdinaryUserCanReadIt() throws Exception {
        String admin = register("news-admin@example.test");
        jdbc.update("UPDATE users SET role='ADMIN' WHERE email=?", "news-admin@example.test");
        entities.clear();
        mvc.perform(get("/api/v1/users/me").header("Authorization", "Bearer " + admin))
                .andExpect(jsonPath("$.data.role").value("ADMIN"));
        long id = create(admin, "NEWS");
        mvc.perform(put("/api/v1/posts/{id}", id).header("Authorization", "Bearer " + admin)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(mapper.writeValueAsBytes(Map.of("title", "updated news", "content", "body", "category", "NEWS"))))
                .andExpect(status().isOk());
        String reader = register("news-viewer@example.test");
        mvc.perform(get("/api/v1/users/me").header("Authorization", "Bearer " + reader))
                .andExpect(jsonPath("$.data.role").value("USER"));
        mvc.perform(get("/api/v1/posts").param("category", "NEWS").header("Authorization", "Bearer " + reader))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data.items[0].title").value("updated news"));
        jdbc.update("UPDATE users SET role='USER' WHERE email=?", "news-admin@example.test");
        entities.clear();
        mvc.perform(put("/api/v1/posts/{id}", id).header("Authorization", "Bearer " + admin)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(mapper.writeValueAsBytes(Map.of("title", "retag", "content", "body", "category", "FREE"))))
                .andExpect(status().isForbidden());
    }

    private String register(String email) throws Exception {
        var response = mvc.perform(post("/api/v1/auth/register").contentType(MediaType.APPLICATION_JSON)
                        .content(mapper.writeValueAsBytes(Map.of("email", email, "password", "Password1!",
                                "nickname", "reader", "role", "ADMIN"))))
                .andExpect(status().isCreated()).andReturn().getResponse().getContentAsString();
        return mapper.readTree(response).at("/data/accessToken").asText();
    }

    private long create(String token, String category) throws Exception {
        var response = mvc.perform(multipart("/api/v1/posts")
                        .file(new MockMultipartFile("payload", "", "application/json",
                                mapper.writeValueAsBytes(Map.of("title", "news", "content", "body", "category", category))))
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isCreated()).andReturn().getResponse().getContentAsString();
        return mapper.readTree(response).at("/data/id").asLong();
    }
}
