package com.petyilgi.media;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.petyilgi.auth.repository.RefreshTokenRepository;
import com.petyilgi.auth.repository.UserRepository;
import com.petyilgi.media.storage.MediaStorage;
import com.petyilgi.support.IntegrationTestSupport;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.transaction.annotation.Transactional;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@AutoConfigureMockMvc
@Transactional
class MediaStorageFailureIntegrationTest extends IntegrationTestSupport {

    @Autowired MockMvc mockMvc;
    @Autowired ObjectMapper objectMapper;
    @Autowired UserRepository userRepository;
    @Autowired RefreshTokenRepository refreshTokenRepository;
    @Autowired JdbcTemplate jdbcTemplate;
    @MockitoBean MediaStorage mediaStorage;

    @BeforeEach
    void setUp() {
        refreshTokenRepository.deleteAll();
        userRepository.deleteAll();
    }

    @Test
    void storageFailureDoesNotInsertMediaRow() throws Exception {
        String token = registerAndGetToken("storage-fail@example.com", "storagefail");
        Long petId = createPet(token, "Mochi");
        doThrow(new IOException("disk full")).when(mediaStorage).store(any(), any(), any(), any());

        mockMvc.perform(multipart("/api/v1/pets/" + petId + "/media")
                        .file(new MockMultipartFile("file", "profile.png", MediaType.IMAGE_PNG_VALUE,
                                "image-bytes".getBytes(StandardCharsets.UTF_8)))
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isInternalServerError());

        Integer count = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM media_resources", Integer.class);
        assertThat(count).isZero();
    }

    private String registerAndGetToken(String email, String nickname) throws Exception {
        MvcResult result = mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "email", email,
                                "password", "Password1!",
                                "nickname", nickname
                        ))))
                .andExpect(status().isCreated())
                .andReturn();
        var data = (Map<?, ?>) objectMapper.readValue(result.getResponse().getContentAsString(), Map.class).get("data");
        return (String) data.get("accessToken");
    }

    private Long createPet(String token, String name) throws Exception {
        MvcResult result = mockMvc.perform(post("/api/v1/pets")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "name", name,
                                "species", "dog",
                                "birthDate", "2022-03-15"
                        ))))
                .andExpect(status().isCreated())
                .andReturn();
        var data = (Map<?, ?>) objectMapper.readValue(result.getResponse().getContentAsString(), Map.class).get("data");
        return ((Number) data.get("id")).longValue();
    }
}
