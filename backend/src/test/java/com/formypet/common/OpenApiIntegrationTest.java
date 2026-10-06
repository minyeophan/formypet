package com.formypet.common;

import com.formypet.auth.JwtService;
import com.formypet.support.IntegrationTestSupport;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.jdbc.core.JdbcTemplate;

import java.util.UUID;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@AutoConfigureMockMvc
class OpenApiIntegrationTest extends IntegrationTestSupport {

    @Autowired
    MockMvc mockMvc;

    @Autowired
    JwtService jwt;

    @Autowired
    JdbcTemplate jdbc;

    @Test
    void swaggerAndApiDocsRequireAuthentication() throws Exception {
        mockMvc.perform(get("/swagger-ui.html"))
                .andExpect(status().isUnauthorized());
        mockMvc.perform(get("/swagger-ui/index.html"))
                .andExpect(status().isUnauthorized());
        mockMvc.perform(get("/v3/api-docs"))
                .andExpect(status().isUnauthorized());
        mockMvc.perform(get("/v3/api-docs/swagger-config"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void apiDocsRenderWithCurrentSpringVersion() throws Exception {
        String email = "openapi-" + UUID.randomUUID() + "@example.test";
        jdbc.update("INSERT INTO users(email, password_hash, nickname) VALUES (?, 'test-only', 'openapi-test')", email);
        long userId = jdbc.queryForObject("SELECT id FROM users WHERE email = ?", Long.class, email);
        try {
        mockMvc.perform(get("/v3/api-docs")
                        .header("Authorization", "Bearer " + jwt.generateAccessToken(userId, 0L)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.openapi").isNotEmpty())
                .andExpect(jsonPath("$.paths['/api/v1/posts/{postId}/comments/{commentId}/reports'].post").exists())
                .andExpect(jsonPath("$.components.schemas.PostCommentReportRequest").exists())
                .andExpect(jsonPath("$.components.schemas.PostCommentReportResponse").exists())
                .andExpect(jsonPath("$.components.schemas.PostCommentReportRequest.properties.reason").exists())
                .andExpect(jsonPath("$.components.schemas.PostCommentReportRequest.properties.detail").exists())
                .andExpect(jsonPath("$.paths['/api/v1/notifications/settings'].patch").exists())
                .andExpect(jsonPath("$.paths['/api/v1/posts/{postId}'].put").exists())
                .andExpect(jsonPath("$.paths['/api/v1/posts/{postId}'].delete").exists())
                .andExpect(jsonPath("$.components.schemas.PostUpdateRequest.properties.title").exists())
                .andExpect(jsonPath("$.components.schemas.PostUpdateRequest.properties.category").exists())
                .andExpect(jsonPath("$.components.schemas.PostUpdateRequest.properties.content").exists())
                .andExpect(jsonPath("$.components.schemas.NotificationSettingsRequest.properties.enabled").exists())
                .andExpect(jsonPath("$.components.schemas.NotificationSettingsResponse.properties.enabled").exists())
                .andExpect(jsonPath("$.components.schemas.RoutineCreateRequest.properties.notificationEnabled").exists())
                .andExpect(jsonPath("$.components.schemas.RoutineUpdateRequest.properties.notificationEnabled").exists())
                .andExpect(jsonPath("$.components.schemas.CareScheduleRequest.properties.reminder").exists())
                .andExpect(jsonPath("$.components.schemas.CareScheduleRequest.properties.reminder.enum").isArray())
                .andExpect(jsonPath("$.components.schemas.NotificationResponse.properties.actorUserId").exists())
                .andExpect(jsonPath("$.components.schemas.NotificationResponse.properties.postId").exists())
                .andExpect(jsonPath("$.components.schemas.NotificationResponse.properties.commentId").exists())
                .andExpect(jsonPath("$.components.securitySchemes.bearerAuth").exists())
                .andExpect(jsonPath("$.paths['/api/v1/pets'].get.security[0].bearerAuth").exists())
                .andExpect(jsonPath("$.paths['/api/v1/notifications/settings'].get.security[0].bearerAuth").exists())
                .andExpect(jsonPath("$.paths['/api/v1/public/media/{mediaId}'].get.security").doesNotExist())
                .andExpect(jsonPath("$.paths['/api/v1/pets'].get.responses['400']").exists())
                .andExpect(jsonPath("$.paths['/api/v1/pets'].get.responses['401']").exists())
                .andExpect(jsonPath("$.paths['/api/v1/pets'].get.responses['403']").exists())
                .andExpect(jsonPath("$.paths['/api/v1/pets'].get.responses['404']").exists())
                .andExpect(jsonPath("$.paths['/api/v1/pets'].get.responses['409']").exists())
                .andExpect(jsonPath("$.paths['/api/v1/auth/login'].post.security").doesNotExist())
                .andExpect(jsonPath("$.components.schemas.RegisterRequest.properties.email").exists())
                .andExpect(jsonPath("$.components.schemas.RegisterRequest.properties.password").exists())
                .andExpect(jsonPath("$.components.schemas.UserProfileUpdateRequest.properties.nickname").exists())
                .andExpect(jsonPath("$.components.schemas.UserProfileResponse.properties.profileImageUrl").exists())
                .andExpect(jsonPath("$.paths['/api/v1/users/me'].get.security[0].bearerAuth").exists());
        } finally {
            jdbc.update("DELETE FROM users WHERE id = ?", userId);
        }
    }
}
