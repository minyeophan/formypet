package com.formypet.user;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.formypet.auth.repository.RefreshTokenRepository;
import com.formypet.auth.repository.UserRepository;
import com.formypet.support.IntegrationTestSupport;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.matchesPattern;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@AutoConfigureMockMvc
@Transactional
@TestPropertySource(properties = "app.media.storage-root=build/profile-media-test-storage")
class UserProfileIntegrationTest extends IntegrationTestSupport {

    @Autowired MockMvc mockMvc;
    @Autowired ObjectMapper objectMapper;
    @Autowired UserRepository userRepository;
    @Autowired RefreshTokenRepository refreshTokenRepository;
    @Autowired JdbcTemplate jdbcTemplate;

    @BeforeEach
    void setUp() {
        jdbcTemplate.update("UPDATE users SET profile_media_id = NULL");
        jdbcTemplate.update("DELETE FROM media_resources");
        refreshTokenRepository.deleteAll();
        userRepository.deleteAll();
    }

    @Test
    void getMyProfileReturnsEmailNicknameAndProfileImageUrl() throws Exception {
        String token = registerAndGetToken("profile@example.com", "초코보호자");

        mockMvc.perform(get("/api/v1/users/me")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.id").isNumber())
                .andExpect(jsonPath("$.data.email").value("profile@example.com"))
                .andExpect(jsonPath("$.data.nickname").value("초코보호자"))
                .andExpect(jsonPath("$.data.profileImageUrl").doesNotExist());
    }

    @Test
    void updateMyProfileChangesNickname() throws Exception {
        String token = registerAndGetToken("rename@example.com", "이전이름");

        mockMvc.perform(patch("/api/v1/users/me")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("nickname", "새이름"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.id").isNumber())
                .andExpect(jsonPath("$.data.email").value("rename@example.com"))
                .andExpect(jsonPath("$.data.nickname").value("새이름"));

        mockMvc.perform(get("/api/v1/users/me")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.id").isNumber())
                .andExpect(jsonPath("$.data.nickname").value("새이름"));
    }

    @Test
    void updateMyProfileWithBlankNicknameReturns400() throws Exception {
        String token = registerAndGetToken("blank-name@example.com", "이름");

        mockMvc.perform(patch("/api/v1/users/me")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("nickname", "   "))))
                .andExpect(status().isBadRequest());
    }

    @Test
    void uploadMyProfileImageStoresMediaAndReturnsProfile() throws Exception {
        String token = registerAndGetToken("image-profile@example.com", "사진유저");

        mockMvc.perform(multipart("/api/v1/users/me/profile-image")
                        .file(image("profile.webp"))
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.id").isNumber())
                .andExpect(jsonPath("$.data.email").value("image-profile@example.com"))
                .andExpect(jsonPath("$.data.nickname").value("사진유저"))
                .andExpect(jsonPath("$.data.profileImageUrl").value(matchesPattern("/api/v1/media/[0-9]+")));

        Integer detachedProfileMedia = jdbcTemplate.queryForObject("""
                SELECT COUNT(*)
                FROM media_resources
                WHERE pet_id IS NULL AND record_id IS NULL
                """, Integer.class);
        assertThat(detachedProfileMedia).isEqualTo(1);
    }

    @Test
    @Transactional(propagation = Propagation.NOT_SUPPORTED)
    void replacingMyProfileImageKeepsOnlyTheLatestMediaAndDeletesThePreviousFileAfterCommit() throws Exception {
        String email = "replace-profile@example.com";
        String token = registerAndGetToken(email, "replace");

        mockMvc.perform(multipart("/api/v1/users/me/profile-image")
                        .file(image("first.webp"))
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isCreated());

        Long previousMediaId = jdbcTemplate.queryForObject(
                "SELECT profile_media_id FROM users WHERE email = ?", Long.class, email);
        String previousStorageKey = jdbcTemplate.queryForObject(
                "SELECT storage_key FROM media_resources WHERE id = ?", String.class, previousMediaId);

        mockMvc.perform(multipart("/api/v1/users/me/profile-image")
                        .file(image("second.webp"))
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isCreated());

        Long latestMediaId = jdbcTemplate.queryForObject(
                "SELECT profile_media_id FROM users WHERE email = ?", Long.class, email);
        String latestStorageKey = jdbcTemplate.queryForObject(
                "SELECT storage_key FROM media_resources WHERE id = ?", String.class, latestMediaId);

        assertThat(latestMediaId).isNotEqualTo(previousMediaId);
        assertThat(jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM media_resources WHERE id = ?", Integer.class, previousMediaId)).isZero();
        assertThat(Files.exists(profileStoragePath(previousStorageKey))).isFalse();
        assertThat(Files.exists(profileStoragePath(latestStorageKey))).isTrue();
    }

    @Test
    void myProfileRequiresAuthentication() throws Exception {
        mockMvc.perform(get("/api/v1/users/me"))
                .andExpect(status().isUnauthorized());
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

    private MockMultipartFile image(String originalName) {
        return new MockMultipartFile("file", originalName, "image/webp",
                "profile-bytes".getBytes(StandardCharsets.UTF_8));
    }

    private Path profileStoragePath(String storageKey) {
        return Path.of("build/profile-media-test-storage").resolve(storageKey);
    }
}
