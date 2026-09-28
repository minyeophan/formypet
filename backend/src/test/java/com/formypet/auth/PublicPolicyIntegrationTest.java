package com.formypet.auth;

import com.formypet.support.IntegrationTestSupport;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.test.web.servlet.MockMvc;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@AutoConfigureMockMvc
class PublicPolicyIntegrationTest extends IntegrationTestSupport {
    @Autowired MockMvc mvc;

    @Test void unpublishedCatalogIsPublicAndDoesNotAdvertiseConsentRequirements() throws Exception {
        mvc.perform(get("/api/v1/public/policies"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.published").value(false))
                .andExpect(jsonPath("$.data.enforcementEnabled").value(false))
                .andExpect(jsonPath("$.data.documents").isEmpty());
    }

    @Test void publicWebPagesExplainPublicationPendingWithoutAuthentication() throws Exception {
        for (String path : new String[]{"/privacy", "/terms"}) {
            mvc.perform(get(path)).andExpect(status().isServiceUnavailable())
                    .andExpect(content().contentTypeCompatibleWith("text/html"))
                    .andExpect(content().string(org.hamcrest.Matchers.containsString("게시 준비 중")));
        }
    }
}
