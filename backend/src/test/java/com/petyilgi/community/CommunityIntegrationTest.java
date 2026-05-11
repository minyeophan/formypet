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
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.util.List;
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
    void createMultipartPostWithImagesAndPollSucceeds() throws Exception {
        String token = registerAndGetToken("post-create@example.com", "creator");

        mockMvc.perform(multipartPost(token, Map.of(
                        "title", "첫 산책 후기",
                        "category", "TRAVEL",
                        "content", "First community post",
                        "poll", Map.of(
                                "question", "다음 산책지는?",
                                "options", List.of("공원", "강변")
                        )
                ), image("walk.webp")))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.id").isNumber())
                .andExpect(jsonPath("$.data.title").value("첫 산책 후기"))
                .andExpect(jsonPath("$.data.category").value("TRAVEL"))
                .andExpect(jsonPath("$.data.content").value("First community post"))
                .andExpect(jsonPath("$.data.likesCount").value(0))
                .andExpect(jsonPath("$.data.commentsCount").value(0))
                .andExpect(jsonPath("$.data.liked").value(false))
                .andExpect(jsonPath("$.data.mediaUrls[0]").value(org.hamcrest.Matchers.matchesPattern("/api/v1/public/media/[0-9]+")))
                .andExpect(jsonPath("$.data.poll.question").value("다음 산책지는?"))
                .andExpect(jsonPath("$.data.poll.options", hasSize(2)))
                .andExpect(jsonPath("$.data.poll.options[0].votesCount").value(0));
    }

    @Test
    void createMultipartPostAcceptsTextPayloadFromReactNativeFormData() throws Exception {
        String token = registerAndGetToken("post-text-payload@example.com", "textpayload");

        mockMvc.perform(multipartPostWithPayloadContentType(token, Map.of(
                        "title", "문자열 payload",
                        "category", "FREE",
                        "content", "React Native FormData payload"
                ), MediaType.TEXT_PLAIN_VALUE))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.title").value("문자열 payload"))
                .andExpect(jsonPath("$.data.category").value("FREE"))
                .andExpect(jsonPath("$.data.content").value("React Native FormData payload"));
    }

    @Test
    void feedSupportsCategoryAndLatestCursorPagination() throws Exception {
        String token = registerAndGetToken("post-feed@example.com", "feed");
        Long freeId = createPost(token, "자유 글", "FREE", "free");
        Long trainingId = createPost(token, "훈련 글", "TRAINING", "training");
        Long newestFreeId = createPost(token, "새 자유 글", "FREE", "newest free");

        MvcResult firstPage = mockMvc.perform(get(POSTS_URL)
                        .header("Authorization", "Bearer " + token)
                        .param("category", "FREE")
                        .param("sort", "latest")
                        .param("limit", "1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items", hasSize(1)))
                .andExpect(jsonPath("$.data.items[0].id").value(newestFreeId))
                .andExpect(jsonPath("$.data.items[0].category").value("FREE"))
                .andExpect(jsonPath("$.data.nextCursor").value(newestFreeId.toString()))
                .andReturn();

        var data = (Map<?, ?>) objectMapper.readValue(firstPage.getResponse().getContentAsString(), Map.class).get("data");
        String nextCursor = data.get("nextCursor").toString();

        mockMvc.perform(get(POSTS_URL)
                        .header("Authorization", "Bearer " + token)
                        .param("category", "FREE")
                        .param("sort", "latest")
                        .param("cursor", nextCursor)
                        .param("limit", "1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items", hasSize(1)))
                .andExpect(jsonPath("$.data.items[0].id").value(freeId));

        mockMvc.perform(get(POSTS_URL)
                        .header("Authorization", "Bearer " + token)
                        .param("category", "TRAINING")
                        .param("sort", "latest")
                        .param("limit", "10"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items", hasSize(1)))
                .andExpect(jsonPath("$.data.items[0].id").value(trainingId));
    }

    @Test
    void feedSupportsPopularCursorPagination() throws Exception {
        String ownerToken = registerAndGetToken("post-popular-owner@example.com", "owner");
        String likerOneToken = registerAndGetToken("post-popular-one@example.com", "one");
        String likerTwoToken = registerAndGetToken("post-popular-two@example.com", "two");
        Long leastPopularId = createPost(ownerToken, "인기 낮음", "FREE", "least");
        Long middlePopularId = createPost(ownerToken, "인기 중간", "FREE", "middle");
        Long mostPopularId = createPost(ownerToken, "인기 높음", "FREE", "most");
        like(likerOneToken, middlePopularId);
        like(likerOneToken, mostPopularId);
        like(likerTwoToken, mostPopularId);

        MvcResult firstPage = mockMvc.perform(get(POSTS_URL)
                        .header("Authorization", "Bearer " + ownerToken)
                        .param("sort", "popular")
                        .param("limit", "2"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items", hasSize(2)))
                .andExpect(jsonPath("$.data.items[0].id").value(mostPopularId))
                .andExpect(jsonPath("$.data.items[1].id").value(middlePopularId))
                .andExpect(jsonPath("$.data.nextCursor").value("1:" + middlePopularId))
                .andReturn();

        var data = (Map<?, ?>) objectMapper.readValue(firstPage.getResponse().getContentAsString(), Map.class).get("data");
        String nextCursor = data.get("nextCursor").toString();

        mockMvc.perform(get(POSTS_URL)
                        .header("Authorization", "Bearer " + ownerToken)
                        .param("sort", "popular")
                        .param("cursor", nextCursor)
                        .param("limit", "2"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items", hasSize(1)))
                .andExpect(jsonPath("$.data.items[0].id").value(leastPopularId));
    }

    @Test
    void likeToggleIncreasesAndDecreasesCount() throws Exception {
        String token = registerAndGetToken("post-like@example.com", "liker");
        Long postId = createPost(token, "좋아요 대상", "FREE", "like target");

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
        Long postId = createPost(token, "중복 좋아요 대상", "FREE", "duplicate like target");

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

    @Test
    void voteCanBeSelectedAndChanged() throws Exception {
        String token = registerAndGetToken("post-vote@example.com", "voter");
        MvcResult result = mockMvc.perform(multipartPost(token, Map.of(
                        "title", "투표 글",
                        "category", "FREE",
                        "content", "vote target",
                        "poll", Map.of(
                                "question", "간식은?",
                                "options", List.of("고구마", "닭가슴살")
                        )
                )))
                .andExpect(status().isCreated())
                .andReturn();
        var post = (Map<?, ?>) objectMapper.readValue(result.getResponse().getContentAsString(), Map.class).get("data");
        var poll = (Map<?, ?>) post.get("poll");
        var options = (List<?>) poll.get("options");
        Long firstOptionId = ((Number) ((Map<?, ?>) options.get(0)).get("id")).longValue();
        Long secondOptionId = ((Number) ((Map<?, ?>) options.get(1)).get("id")).longValue();
        Long postId = ((Number) post.get("id")).longValue();

        mockMvc.perform(post(POSTS_URL + "/" + postId + "/poll/options/" + firstOptionId + "/vote")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.poll.options[0].votesCount").value(1))
                .andExpect(jsonPath("$.data.poll.options[0].votedByMe").value(true))
                .andExpect(jsonPath("$.data.poll.options[1].votesCount").value(0));

        mockMvc.perform(post(POSTS_URL + "/" + postId + "/poll/options/" + secondOptionId + "/vote")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.poll.options[0].votesCount").value(0))
                .andExpect(jsonPath("$.data.poll.options[0].votedByMe").value(false))
                .andExpect(jsonPath("$.data.poll.options[1].votesCount").value(1))
                .andExpect(jsonPath("$.data.poll.options[1].votedByMe").value(true));
    }

    private Long createPost(String token, String title, String category, String content) throws Exception {
        MvcResult result = mockMvc.perform(multipartPost(token, Map.of(
                        "title", title,
                        "category", category,
                        "content", content
                )))
                .andExpect(status().isCreated())
                .andReturn();
        return readId(result);
    }

    private void like(String token, Long postId) throws Exception {
        mockMvc.perform(post(POSTS_URL + "/" + postId + "/like")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk());
    }

    private org.springframework.test.web.servlet.request.MockMultipartHttpServletRequestBuilder multipartPost(
            String token,
            Map<String, Object> payload,
            MockMultipartFile... files
    ) throws Exception {
        return multipartPostWithPayloadContentType(token, payload, MediaType.APPLICATION_JSON_VALUE, files);
    }

    private org.springframework.test.web.servlet.request.MockMultipartHttpServletRequestBuilder multipartPostWithPayloadContentType(
            String token,
            Map<String, Object> payload,
            String payloadContentType,
            MockMultipartFile... files
    ) throws Exception {
        var builder = org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart(POSTS_URL)
                .file(new MockMultipartFile(
                        "payload",
                        "",
                        payloadContentType,
                        objectMapper.writeValueAsBytes(payload)
                ));
        builder.header("Authorization", "Bearer " + token);
        for (MockMultipartFile file : files) {
            builder.file(file);
        }
        return builder;
    }

    private MockMultipartFile image(String originalName) {
        return new MockMultipartFile("files", originalName, "image/webp",
                "image-bytes-1".getBytes(StandardCharsets.UTF_8));
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
