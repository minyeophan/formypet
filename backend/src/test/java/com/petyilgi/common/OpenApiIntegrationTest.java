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
                .andExpect(jsonPath("$.components.schemas.PostCommentReportRequest.properties.detail").exists());
    }
}
