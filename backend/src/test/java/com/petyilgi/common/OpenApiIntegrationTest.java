package com.petyilgi.common;

import com.petyilgi.support.IntegrationTestSupport;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@AutoConfigureMockMvc
class OpenApiIntegrationTest extends IntegrationTestSupport {

    @Autowired
    MockMvc mockMvc;

    @Test
    void apiDocsRenderWithCurrentSpringVersion() throws Exception {
        mockMvc.perform(get("/v3/api-docs"))
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
                .andExpect(jsonPath("$.paths['/api/v1/auth/login'].post.security").doesNotExist());
    }
}
