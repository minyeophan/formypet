package com.petyilgi.media;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.petyilgi.auth.repository.RefreshTokenRepository;
import com.petyilgi.auth.repository.UserRepository;
import com.petyilgi.support.IntegrationTestSupport;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.transaction.TestTransaction;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.transaction.annotation.Transactional;

import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.charset.StandardCharsets;
import java.util.Comparator;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.matchesPattern;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
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
    private static final Path MEDIA_ROOT = Path.of("build/media-test-storage");

    @BeforeEach
    void setUp() throws Exception {
        refreshTokenRepository.deleteAll();
        userRepository.deleteAll();
        deleteDirectory(MEDIA_ROOT);
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
    void recordListIncludesAttachedMediaUrl() throws Exception {
        String token = registerAndGetToken("record-media-list@example.com", "recordmedialist");
        Long petId = createPet(token, "Coco");
        Long recordId = createRecord(token, petId);

        mockMvc.perform(multipart("/api/v1/pets/" + petId + "/records/" + recordId + "/media")
                        .file(image("poop.webp"))
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isCreated());

        mockMvc.perform(get("/api/v1/pets/" + petId + "/records")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data[0].mediaUrls[0]").value(matchesPattern("/api/v1/media/[0-9]+")));
    }

    @Test
    void recordDetailIncludesAttachedMediaUrl() throws Exception {
        String token = registerAndGetToken("record-media-detail@example.com", "recordmediadetail");
        Long petId = createPet(token, "Coco");
        Long recordId = createRecord(token, petId);

        mockMvc.perform(multipart("/api/v1/pets/" + petId + "/records/" + recordId + "/media")
                        .file(image("poop.webp"))
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isCreated());

        mockMvc.perform(get("/api/v1/pets/" + petId + "/records/" + recordId)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.mediaUrls[0]").value(matchesPattern("/api/v1/media/[0-9]+")));
    }

    @Test
    void deletingRecordDeletesMediaRowAndStoredFileAfterCommit() throws Exception {
        String token = registerAndGetToken("record-media-delete@example.com", "recordmediadelete");
        Long petId = createPet(token, "Coco");
        Long recordId = createRecord(token, petId);

        mockMvc.perform(multipart("/api/v1/pets/" + petId + "/records/" + recordId + "/media")
                        .file(image("poop.webp"))
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isCreated());

        String storageKey = jdbcTemplate.queryForObject("""
                SELECT storage_key
                FROM media_resources
                WHERE record_id = ?
                """, String.class, recordId);
        Path storedFile = MEDIA_ROOT.resolve(storageKey);
        assertThat(Files.exists(storedFile)).isTrue();

        mockMvc.perform(delete("/api/v1/pets/" + petId + "/records/" + recordId)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isNoContent());

        Integer countBeforeCommit = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM media_resources WHERE record_id = ?",
                Integer.class,
                recordId
        );
        assertThat(countBeforeCommit).isZero();
        assertThat(Files.exists(storedFile)).isTrue();

        TestTransaction.flagForCommit();
        TestTransaction.end();

        assertThat(Files.exists(storedFile)).isFalse();
        assertThat(countFiles(MEDIA_ROOT)).isZero();

        TestTransaction.start();
    }

    @Test
    void webpUploadUsesExtensionContentTypeWhenRequestTypeIsGeneric() throws Exception {
        String token = registerAndGetToken("webp-content-type@example.com", "webptype");
        Long petId = createPet(token, "Dubu");

        MvcResult result = mockMvc.perform(multipart("/api/v1/pets/" + petId + "/media")
                        .file(new MockMultipartFile("file", "photo.webp", MediaType.APPLICATION_OCTET_STREAM_VALUE,
                                "image-bytes-1".getBytes(StandardCharsets.UTF_8)))
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.contentType").value("image/webp"))
                .andReturn();

        Long mediaId = readId(result);
        mockMvc.perform(get("/api/v1/media/" + mediaId)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(header().string("Content-Type", "image/webp"));
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
    void privateMediaCannotBeReadFromPublicEndpoint() throws Exception {
        String token = registerAndGetToken("private-public-media@example.com", "privatepublic");
        Long petId = createPet(token, "Bori");
        Long mediaId = uploadMedia(token, petId, "owner.jpg");

        mockMvc.perform(get("/api/v1/public/media/" + mediaId))
                .andExpect(status().isForbidden());
    }

    @Test
    void communityPublicMediaCanBeReadWithoutAuthentication() throws Exception {
        String token = registerAndGetToken("community-public-media@example.com", "publicmedia");
        MvcResult result = mockMvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart("/api/v1/posts")
                        .file(new MockMultipartFile(
                                "payload",
                                "",
                                MediaType.APPLICATION_JSON_VALUE,
                                objectMapper.writeValueAsBytes(Map.of(
                                        "title", "사진 글",
                                        "category", "FREE",
                                        "content", "public image"
                                ))
                        ))
                        .file(new MockMultipartFile("files", "community.webp", "image/webp",
                                "image-bytes-1".getBytes(StandardCharsets.UTF_8)))
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.mediaUrls[0]").value(matchesPattern("/api/v1/public/media/[0-9]+")))
                .andReturn();

        var data = (Map<?, ?>) objectMapper.readValue(result.getResponse().getContentAsString(), Map.class).get("data");
        var mediaUrls = (java.util.List<?>) data.get("mediaUrls");
        String publicUrl = mediaUrls.getFirst().toString();

        mockMvc.perform(get(publicUrl))
                .andExpect(status().isOk())
                .andExpect(header().string("Content-Type", "image/webp"))
                .andExpect(content().bytes("image-bytes-1".getBytes(StandardCharsets.UTF_8)));
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

    @Test
    void databaseInsertFailureDeletesStoredFile() throws Exception {
        String token = registerAndGetToken("media-db-fail@example.com", "dbfail");
        Long petId = createPet(token, "Dubu");
        String longName = "a".repeat(260) + ".png";

        mockMvc.perform(multipart("/api/v1/pets/" + petId + "/media")
                        .file(new MockMultipartFile("file", longName, MediaType.IMAGE_PNG_VALUE,
                                "image-bytes-1".getBytes(StandardCharsets.UTF_8)))
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isInternalServerError());

        Integer count = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM media_resources", Integer.class);
        assertThat(count).isZero();
        assertThat(countFiles(MEDIA_ROOT)).isZero();
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

    private long countFiles(Path root) throws Exception {
        if (!Files.exists(root)) {
            return 0;
        }
        try (var paths = Files.walk(root)) {
            return paths.filter(Files::isRegularFile).count();
        }
    }

    private void deleteDirectory(Path root) throws Exception {
        if (!Files.exists(root)) {
            return;
        }
        try (var paths = Files.walk(root)) {
            for (Path path : paths.sorted(Comparator.reverseOrder()).toList()) {
                Files.deleteIfExists(path);
            }
        }
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
