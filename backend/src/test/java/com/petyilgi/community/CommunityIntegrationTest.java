package com.petyilgi.community;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.petyilgi.auth.repository.RefreshTokenRepository;
import com.petyilgi.auth.repository.UserRepository;
import com.petyilgi.support.IntegrationTestSupport;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.transaction.annotation.Transactional;

import java.util.Map;

import static org.hamcrest.Matchers.hasSize;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@AutoConfigureMockMvc
@Transactional
class CommunityIntegrationTest extends IntegrationTestSupport {

    @Autowired MockMvc mockMvc;
    @Autowired ObjectMapper objectMapper;
    @Autowired UserRepository userRepository;
    @Autowired RefreshTokenRepository refreshTokenRepository;

    private static final String AUTH_URL = "/api/v1/auth/register";
    private static final String POSTS_URL = "/api/v1/posts";

    @BeforeEach
    void setUp() {
        refreshTokenRepository.deleteAll();
        userRepository.deleteAll();
    }

    @Test
    void createPostSucceeds() throws Exception {
        String token = registerAndGetToken("post-create@example.com", "creator");

        mockMvc.perform(post(POSTS_URL)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "content", "First community post",
                                "petSpecies", "dog"
                        ))))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.id").isNumber())
                .andExpect(jsonPath("$.data.content").value("First community post"))
                .andExpect(jsonPath("$.data.petSpecies").value("dog"))
                .andExpect(jsonPath("$.data.likesCount").value(0))
                .andExpect(jsonPath("$.data.liked").value(false));
    }

    @Test
    void feedReturnsCursorPagination() throws Exception {
        String token = registerAndGetToken("post-feed@example.com", "feed");
        Long olderId = createPost(token, "older");
        Long middleId = createPost(token, "middle");
        Long newestId = createPost(token, "newest");

        MvcResult firstPage = mockMvc.perform(get(POSTS_URL)
                        .header("Authorization", "Bearer " + token)
                        .param("limit", "2"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items", hasSize(2)))
                .andExpect(jsonPath("$.data.items[0].id").value(newestId))
                .andExpect(jsonPath("$.data.items[1].id").value(middleId))
                .andExpect(jsonPath("$.data.nextCursor").value(middleId))
                .andReturn();

        var data = (Map<?, ?>) objectMapper.readValue(firstPage.getResponse().getContentAsString(), Map.class).get("data");
        String nextCursor = data.get("nextCursor").toString();

        mockMvc.perform(get(POSTS_URL)
                        .header("Authorization", "Bearer " + token)
                        .param("cursor", nextCursor)
                        .param("limit", "2"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items", hasSize(1)))
                .andExpect(jsonPath("$.data.items[0].id").value(olderId))
                .andExpect(jsonPath("$.data.nextCursor").doesNotExist());
    }

    @Test
    void likeToggleIncreasesAndDecreasesCount() throws Exception {
        String token = registerAndGetToken("post-like@example.com", "liker");
        Long postId = createPost(token, "like target");

        mockMvc.perform(post(POSTS_URL + "/" + postId + "/like")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.liked").value(true))
                .andExpect(jsonPath("$.data.likesCount").value(1));

        mockMvc.perform(post(POSTS_URL + "/" + postId + "/like")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.liked").value(false))
                .andExpect(jsonPath("$.data.likesCount").value(0));
    }

    @Test
    void duplicateLikeNeverCreatesMoreThanOneLikePerUser() throws Exception {
        String token = registerAndGetToken("post-duplicate-like@example.com", "duplicate");
        Long postId = createPost(token, "duplicate like target");

        mockMvc.perform(post(POSTS_URL + "/" + postId + "/like")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.likesCount").value(1));

        mockMvc.perform(post(POSTS_URL + "/" + postId + "/like")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.likesCount").value(0));

        mockMvc.perform(post(POSTS_URL + "/" + postId + "/like")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.likesCount").value(1));
    }

    private Long createPost(String token, String content) throws Exception {
        MvcResult result = mockMvc.perform(post(POSTS_URL)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "content", content,
                                "petSpecies", "cat"
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

    private Long readId(MvcResult result) throws Exception {
        var data = (Map<?, ?>) objectMapper.readValue(result.getResponse().getContentAsString(), Map.class).get("data");
        return ((Number) data.get("id")).longValue();
    }
}
