package com.petyilgi.media;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.petyilgi.auth.repository.RefreshTokenRepository;
import com.petyilgi.auth.repository.UserRepository;
import com.petyilgi.support.IntegrationTestSupport;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.matchesPattern;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@AutoConfigureMockMvc
@Transactional
@TestPropertySource(properties = "app.media.storage-root=build/media-test-storage")
class MediaIntegrationTest extends IntegrationTestSupport {

    @Autowired MockMvc mockMvc;
    @Autowired ObjectMapper objectMapper;
    @Autowired UserRepository userRepository;
    @Autowired RefreshTokenRepository refreshTokenRepository;
    @Autowired JdbcTemplate jdbcTemplate;

    private static final String AUTH_URL = "/api/v1/auth/register";
    private static final String PETS_URL = "/api/v1/pets";

    @BeforeEach
    void setUp() {
        refreshTokenRepository.deleteAll();
        userRepository.deleteAll();
    }

    @Test
    void uploadPetProfileMediaSucceeds() throws Exception {
        String token = registerAndGetToken("pet-media@example.com", "petmedia");
        Long petId = createPet(token, "Mochi");

        mockMvc.perform(multipart("/api/v1/pets/" + petId + "/media")
                        .file(image("profile.png"))
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.id").isNumber())
                .andExpect(jsonPath("$.data.url").value(matchesPattern("/api/v1/media/[0-9]+")))
                .andExpect(jsonPath("$.data.originalName").value("profile.png"))
                .andExpect(jsonPath("$.data.contentType").value(MediaType.IMAGE_PNG_VALUE))
                .andExpect(jsonPath("$.data.fileSize").value(13))
                .andExpect(jsonPath("$.data.status").value("STORED"));
    }

    @Test
    void uploadRecordMediaSucceeds() throws Exception {
        String token = registerAndGetToken("record-media@example.com", "recordmedia");
        Long petId = createPet(token, "Coco");
        Long recordId = createRecord(token, petId);

        mockMvc.perform(multipart("/api/v1/pets/" + petId + "/records/" + recordId + "/media")
                        .file(image("walk.webp"))
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.originalName").value("walk.webp"))
                .andExpect(jsonPath("$.data.contentType").value("image/webp"))
                .andExpect(jsonPath("$.data.status").value("STORED"));
    }

    @Test
    void otherUserMediaReadReturns403() throws Exception {
        String ownerToken = registerAndGetToken("media-owner@example.com", "owner");
        String otherToken = registerAndGetToken("media-other@example.com", "other");
        Long petId = createPet(ownerToken, "Bori");
        Long mediaId = uploadMedia(ownerToken, petId, "owner.jpg");

        mockMvc.perform(get("/api/v1/media/" + mediaId)
                        .header("Authorization", "Bearer " + otherToken))
                .andExpect(status().isForbidden());
    }

    @Test
    void invalidExtensionReturns400AndDoesNotInsertRow() throws Exception {
        String token = registerAndGetToken("bad-ext@example.com", "badext");
        Long petId = createPet(token, "Nabi");

        mockMvc.perform(multipart("/api/v1/pets/" + petId + "/media")
                        .file(new MockMultipartFile("file", "notes.txt", MediaType.TEXT_PLAIN_VALUE,
                                "not an image".getBytes(StandardCharsets.UTF_8)))
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isBadRequest());

        Integer count = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM media_resources", Integer.class);
        assertThat(count).isZero();
    }

    @Test
    void fileOverFiveMegabytesReturns400AndDoesNotInsertRow() throws Exception {
        String token = registerAndGetToken("large-media@example.com", "large");
        Long petId = createPet(token, "Dubu");
        byte[] largeFile = new byte[(5 * 1024 * 1024) + 1];

        mockMvc.perform(multipart("/api/v1/pets/" + petId + "/media")
                        .file(new MockMultipartFile("file", "large.png", MediaType.IMAGE_PNG_VALUE, largeFile))
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isBadRequest());

        Integer count = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM media_resources", Integer.class);
        assertThat(count).isZero();
    }

    private Long uploadMedia(String token, Long petId, String originalName) throws Exception {
        MvcResult result = mockMvc.perform(multipart("/api/v1/pets/" + petId + "/media")
                        .file(image(originalName))
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isCreated())
                .andReturn();
        return readId(result);
    }

    private MockMultipartFile image(String originalName) {
        String contentType = originalName.endsWith(".webp") ? "image/webp" : MediaType.IMAGE_PNG_VALUE;
        return new MockMultipartFile("file", originalName, contentType,
                "image-bytes-1".getBytes(StandardCharsets.UTF_8));
    }

    private Long createRecord(String token, Long petId) throws Exception {
        MvcResult result = mockMvc.perform(post("/api/v1/pets/" + petId + "/records")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "typeId", "walk",
                                "date", "2026-05-09",
                                "time", "09:00",
                                "detail", Map.of("distance", 1.2)
                        ))))
                .andExpect(status().isCreated())
                .andReturn();
        return readId(result);
    }

    private String registerAndGetToken(String email, String nickname) throws Exception {
        MvcResult result = mockMvc.perform(post(AUTH_URL)
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
        MvcResult result = mockMvc.perform(post(PETS_URL)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "name", name,
                                "species", "dog",
                                "birthDate", "2022-03-15"
                        ))))
                .andExpect(status().isCreated())
                .andReturn();
        return readId(result);
    }

    private Long readId(MvcResult result) throws Exception {
        var data = (Map<?, ?>) objectMapper.readValue(result.getResponse().getContentAsString(), Map.class).get("data");
        return ((Number) data.get("id")).longValue();
    }
}
