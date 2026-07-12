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
import org.springframework.test.context.TestPropertySource;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Map;

import static org.hamcrest.Matchers.hasSize;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@AutoConfigureMockMvc
@Transactional
@TestPropertySource(properties = "app.media.storage-root=build/community-media-test-storage")
class CommunityIntegrationTest extends IntegrationTestSupport {

    @Autowired MockMvc mockMvc;
    @Autowired ObjectMapper objectMapper;
    @Autowired UserRepository userRepository;
    @Autowired RefreshTokenRepository refreshTokenRepository;
    @Autowired org.springframework.jdbc.core.JdbcTemplate jdbcTemplate;
    @Autowired CommunityService communityService;

    private static final String AUTH_URL = "/api/v1/auth/register";
    private static final String POSTS_URL = "/api/v1/posts";

    @BeforeEach
    void setUp() {
        jdbcTemplate.update("UPDATE users SET profile_media_id = NULL");
        jdbcTemplate.update("DELETE FROM media_resources");
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
    void createPostAcceptsTitleWithExactlyThirtyCharacters() throws Exception {
        String token = registerAndGetToken("post-title-30@example.com", "title30");
        String title = "a".repeat(30);

        mockMvc.perform(multipartPost(token, Map.of(
                        "title", title,
                        "category", "FREE",
                        "content", "Thirty character title"
                )))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.title").value(title));
    }

    @Test
    void createPostRejectsTitleWithThirtyOneCharacters() throws Exception {
        String token = registerAndGetToken("post-title-31@example.com", "title31");

        mockMvc.perform(multipartPost(token, Map.of(
                        "title", "a".repeat(31),
                        "category", "FREE",
                        "content", "Too long title"
                )))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.title").value("Invalid Input"))
                .andExpect(jsonPath("$.errorCode").value("INVALID_INPUT"))
                .andExpect(jsonPath("$.detail").value("Post title must be 30 characters or fewer."));
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
                .andExpect(jsonPath("$.data.items[0].id").value(freeId))
                .andExpect(jsonPath("$.data.nextCursor").doesNotExist());

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
        Long otherLeastPopularId = createPost(ownerToken, "인기 조금 낮음", "FREE", "other least");
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
                .andExpect(jsonPath("$.data.items", hasSize(2)))
                .andExpect(jsonPath("$.data.items[0].id").value(otherLeastPopularId))
                .andExpect(jsonPath("$.data.items[1].id").value(leastPopularId))
                .andExpect(jsonPath("$.data.nextCursor").doesNotExist());
    }

    @Test
    void feedPaginatesAllSearchResultsForLatestAndPopular() throws Exception {
        String ownerToken = registerAndGetToken("post-search-page-owner@example.com", "pageowner");
        String likerOneToken = registerAndGetToken("post-search-page-one@example.com", "pageone");
        String likerTwoToken = registerAndGetToken("post-search-page-two@example.com", "pagetwo");
        Long firstId = createPost(ownerToken, "검색 첫째", "FREE", "first");
        Long secondId = createPost(ownerToken, "검색 둘째", "FREE", "second");
        Long thirdId = createPost(ownerToken, "검색 셋째", "FREE", "third");
        createPost(ownerToken, "제외 게시글", "FREE", "excluded");
        like(likerOneToken, secondId);
        like(likerOneToken, thirdId);
        like(likerTwoToken, thirdId);

        assertSearchPages(ownerToken, "latest", thirdId, secondId, firstId, secondId.toString());
        assertSearchPages(ownerToken, "popular", thirdId, secondId, firstId, "1:" + secondId);
    }

    @Test
    void feedSearchesTitleAndContentAndCombinesCategory() throws Exception {
        String token = registerAndGetToken("post-search@example.com", "searcher");
        Long titleMatchId = createPost(token, "강아지 산책", "FREE", "오늘 공원에 다녀왔어요");
        Long contentMatchId = createPost(token, "주말 이야기", "FREE", "강아지와 함께 쉬었어요");
        createPost(token, "고양이 이야기", "FREE", "창가에서 쉬었어요");
        createPost(token, "강아지 훈련", "TRAINING", "기다려 연습");

        mockMvc.perform(get(POSTS_URL)
                        .header("Authorization", "Bearer " + token)
                        .param("keyword", "강아지")
                        .param("category", "FREE"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items", hasSize(2)))
                .andExpect(jsonPath("$.data.items[0].id").value(contentMatchId))
                .andExpect(jsonPath("$.data.items[1].id").value(titleMatchId))
                .andExpect(jsonPath("$.data.nextCursor").doesNotExist());

        mockMvc.perform(get(POSTS_URL)
                        .header("Authorization", "Bearer " + token)
                        .param("keyword", "검색결과없음"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items", hasSize(0)))
                .andExpect(jsonPath("$.data.nextCursor").doesNotExist());
    }

    @Test
    void feedRejectsKeywordOutsideCodePointLengthRange() throws Exception {
        String token = registerAndGetToken("post-search-length@example.com", "length");

        for (String keyword : List.of("가", "가".repeat(21))) {
            mockMvc.perform(get(POSTS_URL)
                            .header("Authorization", "Bearer " + token)
                            .param("keyword", keyword))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.title").value("Invalid Input"))
                    .andExpect(jsonPath("$.status").value(400))
                    .andExpect(jsonPath("$.detail")
                            .value("Search keyword must be between 2 and 20 characters."))
                    .andExpect(jsonPath("$.errorCode").value("INVALID_INPUT"));
        }
    }

    @Test
    void feedTreatsMissingEmptyAndBlankKeywordAsNoFilter() throws Exception {
        String token = registerAndGetToken("post-search-blank@example.com", "blank");
        createPost(token, "첫 게시글", "FREE", "first");
        createPost(token, "둘째 게시글", "FREE", "second");

        mockMvc.perform(get(POSTS_URL)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items", hasSize(2)));
        mockMvc.perform(get(POSTS_URL)
                        .header("Authorization", "Bearer " + token)
                        .param("keyword", ""))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items", hasSize(2)));
        mockMvc.perform(get(POSTS_URL)
                        .header("Authorization", "Bearer " + token)
                        .param("keyword", "   "))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items", hasSize(2)));
    }

    @Test
    void feedAcceptsTrimmedCodePointBoundariesAndMatchesCaseInsensitively() throws Exception {
        String token = registerAndGetToken("post-search-boundary@example.com", "boundary");
        Long twoCodePointId = createPost(token, "🐶개 이야기", "FREE", "emoji");
        String twentyCodePoints = "가".repeat(20);
        Long twentyCodePointId = createPost(token, twentyCodePoints, "FREE", "twenty");
        Long caseInsensitiveId = createPost(token, "CASE Search", "FREE", "case");

        assertSingleSearchResult(token, "  🐶개  ", twoCodePointId);
        assertSingleSearchResult(token, twentyCodePoints, twentyCodePointId);
        assertSingleSearchResult(token, "case", caseInsensitiveId);
    }

    @Test
    void feedTreatsLikeWildcardsAndSqlSyntaxAsLiteralText() throws Exception {
        String token = registerAndGetToken("post-search-literal@example.com", "literal");
        Long percentId = createPost(token, "할인 50% 적용", "FREE", "percent");
        createPost(token, "할인 500 적용", "FREE", "not percent");
        Long underscoreId = createPost(token, "코드 a_b", "FREE", "underscore");
        createPost(token, "코드 axb", "FREE", "not underscore");
        Long exclamationId = createPost(token, "느낌표 !!", "FREE", "exclamation");

        assertSingleSearchResult(token, "50%", percentId);
        assertSingleSearchResult(token, "a_b", underscoreId);
        assertSingleSearchResult(token, "!!", exclamationId);

        mockMvc.perform(get(POSTS_URL)
                        .header("Authorization", "Bearer " + token)
                        .param("keyword", "%' OR 1=1 --"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items", hasSize(0)));
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

    @Test
    void postDetailReturnsPostAndMissingPostReturnsPostNotFound() throws Exception {
        String token = registerAndGetToken("post-detail@example.com", "detail");
        Long postId = createPost(token, "상세 글", "FREE", "detail target");

        mockMvc.perform(get(POSTS_URL + "/" + postId)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.id").value(postId))
                .andExpect(jsonPath("$.data.title").value("상세 글"));

        mockMvc.perform(get(POSTS_URL + "/999999/comments")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.errorCode").value("POST_NOT_FOUND"));

        mockMvc.perform(get(POSTS_URL + "/999999")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.errorCode").value("POST_NOT_FOUND"));
    }

    @Test
    void commentsAreTrimmedPaginatedAndIncreaseOnlyTheirPostCount() throws Exception {
        String token = registerAndGetToken("post-comment@example.com", "commenter");
        Long firstPostId = createPost(token, "첫 글", "FREE", "first");
        Long secondPostId = createPost(token, "둘째 글", "FREE", "second");

        mockMvc.perform(post(POSTS_URL + "/" + firstPostId + "/comments")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"content\":\"  첫 댓글  \"}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.content").value("첫 댓글"))
                .andExpect(jsonPath("$.data.commentsCount").value(1));

        mockMvc.perform(post(POSTS_URL + "/" + firstPostId + "/comments")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"content\":\"둘째 댓글\"}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.commentsCount").value(2));

        mockMvc.perform(get(POSTS_URL + "/" + firstPostId + "/comments")
                        .header("Authorization", "Bearer " + token)
                        .param("limit", "1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items", hasSize(1)))
                .andExpect(jsonPath("$.data.items[0].content").value("둘째 댓글"))
                .andExpect(jsonPath("$.data.nextCursor").isNotEmpty());

        mockMvc.perform(get(POSTS_URL + "/" + secondPostId)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.commentsCount").value(0));
    }

    @Test
    void commentsExposeAuthenticatedAuthorProfileImageUrl() throws Exception {
        String authorToken = registerAndGetToken("comment-profile-author@example.com", "author");
        String viewerToken = registerAndGetToken("comment-profile-viewer@example.com", "viewer");
        Long authorId = readUserId(authorToken);
        uploadProfileImage(authorToken);
        Long postId = createPost(authorToken, "profile comment", "FREE", "profile target");

        mockMvc.perform(post(POSTS_URL + "/" + postId + "/comments")
                        .header("Authorization", "Bearer " + authorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"content\":\"profile comment\"}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.authorProfileImageUrl")
                        .value("/api/v1/users/" + authorId + "/profile-image"));

        mockMvc.perform(get(POSTS_URL + "/" + postId + "/comments")
                        .header("Authorization", "Bearer " + viewerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items[0].authorProfileImageUrl")
                        .value("/api/v1/users/" + authorId + "/profile-image"));

        mockMvc.perform(get("/api/v1/users/" + authorId + "/profile-image")
                        .header("Authorization", "Bearer " + viewerToken))
                .andExpect(status().isOk())
                .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.content()
                        .contentType("image/png"))
                .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.content()
                        .bytes("profile-image-bytes".getBytes(StandardCharsets.UTF_8)));

        mockMvc.perform(get("/api/v1/users/" + authorId + "/profile-image"))
                .andExpect(status().isUnauthorized());

        Long viewerId = readUserId(viewerToken);
        mockMvc.perform(get("/api/v1/users/" + viewerId + "/profile-image")
                        .header("Authorization", "Bearer " + authorToken))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.errorCode").value("PROFILE_IMAGE_NOT_FOUND"));
    }

    @Test
    void blankCommentIsRejected() throws Exception {
        String token = registerAndGetToken("blank-comment@example.com", "blankcomment");
        Long postId = createPost(token, "댓글 검증", "FREE", "comment validation");

        mockMvc.perform(post(POSTS_URL + "/" + postId + "/comments")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"content\":\"   \"}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void nullCommentRequestIsRejectedBeforeParentAccess() throws Exception {
        String email = "null-comment-request@example.com";
        String token = registerAndGetToken(email, "nullrequest");
        Long postId = createPost(token, "null request", "FREE", "comment validation");

        IllegalArgumentException exception = assertThrows(
                IllegalArgumentException.class,
                () -> communityService.createComment(email, postId, null));
        assertEquals("Comment content must be between 1 and 1000 characters.", exception.getMessage());
    }

    @Test
    void commentAuthorCanEditComment() throws Exception {
        String token = registerAndGetToken("comment-edit@example.com", "editor");
        Long postId = createPost(token, "수정 글", "FREE", "body");
        Long commentId = createComment(token, postId, "before", null);

        mockMvc.perform(patch(POSTS_URL + "/" + postId + "/comments/" + commentId)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"content\":\"  after  \"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.content").value("after"))
                .andExpect(jsonPath("$.data.updatedAt").isNotEmpty())
                .andExpect(jsonPath("$.data.deleted").value(false));

        mockMvc.perform(get(POSTS_URL + "/" + postId + "/comments")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items[0].content").value("after"));
    }

    @Test
    void postAuthorCanSoftDeleteRootWhileRepliesRemainVisible() throws Exception {
        String postAuthorToken = registerAndGetToken("post-author-delete@example.com", "postauthor");
        String commentAuthorToken = registerAndGetToken("comment-author-delete@example.com", "commentauthor");
        Long postId = createPost(postAuthorToken, "삭제 글", "FREE", "body");
        Long rootId = createComment(commentAuthorToken, postId, "root content", null);
        Long replyId = createComment(postAuthorToken, postId, "active reply", rootId);

        mockMvc.perform(delete(POSTS_URL + "/" + postId + "/comments/" + rootId)
                        .header("Authorization", "Bearer " + postAuthorToken))
                .andExpect(status().isNoContent());

        mockMvc.perform(get(POSTS_URL + "/" + postId + "/comments")
                        .header("Authorization", "Bearer " + postAuthorToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items[0].id").value(rootId))
                .andExpect(jsonPath("$.data.items[0].deleted").value(true))
                .andExpect(jsonPath("$.data.items[0].userId").doesNotExist())
                .andExpect(jsonPath("$.data.items[0].content").doesNotExist())
                .andExpect(jsonPath("$.data.items[0].replyCount").value(1))
                .andExpect(jsonPath("$.data.items[0].replies[0].id").value(replyId))
                .andExpect(jsonPath("$.data.items[0].commentsCount").value(1));

        mockMvc.perform(post(POSTS_URL + "/" + postId + "/comments")
                        .header("Authorization", "Bearer " + postAuthorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "content", "new reply", "parentCommentId", rootId))))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.errorCode").value("COMMENT_NOT_FOUND"));

        mockMvc.perform(delete(POSTS_URL + "/" + postId + "/comments/" + replyId)
                        .header("Authorization", "Bearer " + postAuthorToken))
                .andExpect(status().isNoContent());
        mockMvc.perform(get(POSTS_URL + "/" + postId + "/comments")
                        .header("Authorization", "Bearer " + postAuthorToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items", hasSize(0)));
        mockMvc.perform(get(POSTS_URL + "/" + postId + "/comments/" + rootId)
                        .header("Authorization", "Bearer " + postAuthorToken))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.errorCode").value("COMMENT_NOT_FOUND"));
    }

    @Test
    void commentReportStoresSnapshotAndRejectsDuplicateAndSelfReport() throws Exception {
        String authorToken = registerAndGetToken("report-author@example.com", "reportauthor");
        String reporterToken = registerAndGetToken("reporter@example.com", "reporter");
        Long postId = createPost(authorToken, "신고 글", "FREE", "body");
        Long commentId = createComment(authorToken, postId, "reported snapshot", null);

        String reportBody = "{\"reason\":\"SPAM\",\"detail\":\"반복 광고\"}";
        mockMvc.perform(post(POSTS_URL + "/" + postId + "/comments/" + commentId + "/reports")
                        .header("Authorization", "Bearer " + reporterToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(reportBody))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.reason").value("SPAM"));

        assertEquals("reported snapshot", jdbcTemplate.queryForObject(
                "SELECT content_snapshot FROM post_comment_reports WHERE comment_id = ?", String.class, commentId));

        mockMvc.perform(post(POSTS_URL + "/" + postId + "/comments/" + commentId + "/reports")
                        .header("Authorization", "Bearer " + reporterToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(reportBody))
                .andExpect(status().isConflict());

        mockMvc.perform(post(POSTS_URL + "/" + postId + "/comments/" + commentId + "/reports")
                        .header("Authorization", "Bearer " + authorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"reason\":\"ABUSE\"}"))
                .andExpect(status().isBadRequest());

        mockMvc.perform(post(POSTS_URL + "/" + postId + "/comments/" + commentId + "/reports")
                        .header("Authorization", "Bearer " + reporterToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"reason\":\"OTHER\"}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void commentReportTrimsDetailAndRejectsTooLongDetail() throws Exception {
        String authorToken = registerAndGetToken("report-detail-author@example.com", "reportdetailauthor");
        String reporterToken = registerAndGetToken("report-detail-reporter@example.com", "reportdetailreporter");
        Long postId = createPost(authorToken, "report detail post", "FREE", "body");
        Long commentId = createComment(authorToken, postId, "detail target", null);

        mockMvc.perform(post(POSTS_URL + "/" + postId + "/comments/" + commentId + "/reports")
                        .header("Authorization", "Bearer " + reporterToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"reason\":\"OTHER\",\"detail\":\"  custom reason  \"}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.detail").value("custom reason"));

        String storedDetail = jdbcTemplate.queryForObject(
                "SELECT detail FROM post_comment_reports WHERE comment_id = ?",
                String.class,
                commentId);
        assertEquals("custom reason", storedDetail);

        String secondReporterToken = registerAndGetToken("report-detail-long@example.com", "reportdetaillong");
        Long secondCommentId = createComment(authorToken, postId, "long detail target", null);
        mockMvc.perform(post(POSTS_URL + "/" + postId + "/comments/" + secondCommentId + "/reports")
                        .header("Authorization", "Bearer " + secondReporterToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "reason", "SPAM",
                                "detail", "x".repeat(501)))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorCode").value("VALIDATION_FAILED"))
                .andExpect(jsonPath("$.fieldErrors.detail").isNotEmpty());
    }

    @Test
    void deletedCommentCannotBeReported() throws Exception {
        String authorToken = registerAndGetToken("report-deleted-author@example.com", "reportdeletedauthor");
        String reporterToken = registerAndGetToken("report-deleted-reporter@example.com", "reportdeletedreporter");
        Long postId = createPost(authorToken, "report deleted post", "FREE", "body");
        Long commentId = createComment(authorToken, postId, "deleted report target", null);

        mockMvc.perform(delete(POSTS_URL + "/" + postId + "/comments/" + commentId)
                        .header("Authorization", "Bearer " + authorToken))
                .andExpect(status().isNoContent());

        mockMvc.perform(post(POSTS_URL + "/" + postId + "/comments/" + commentId + "/reports")
                        .header("Authorization", "Bearer " + reporterToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"reason\":\"SPAM\"}"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.errorCode").value("COMMENT_NOT_FOUND"));
    }

    @Test
    void repliesAreLimitedPagedAndCannotBeNested() throws Exception {
        String token = registerAndGetToken("reply@example.com", "reply-user");
        Long postId = createPost(token, "reply post", "FREE", "body");
        Long rootId = createComment(token, postId, "root", null);
        Long oldestReplyId = null;
        Long newestReplyId = null;
        for (int i = 1; i <= 21; i++) {
            Long id = createComment(token, postId, "reply-" + i, rootId);
            if (i == 1) oldestReplyId = id;
            newestReplyId = id;
        }

        mockMvc.perform(get(POSTS_URL + "/" + postId + "/comments")
                        .header("Authorization", "Bearer " + token)
                        .param("replyLimit", "3"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items[0].replyCount").value(21))
                .andExpect(jsonPath("$.data.items[0].replies", hasSize(3)))
                .andExpect(jsonPath("$.data.items[0].replies[2].id").value(newestReplyId))
                .andExpect(jsonPath("$.data.items[0].repliesNextCursor").isNotEmpty())
                .andExpect(jsonPath("$.data.items[0].commentsCount").value(22));

        mockMvc.perform(get(POSTS_URL + "/" + postId + "/comments/" + rootId + "/replies")
                        .header("Authorization", "Bearer " + token)
                        .param("limit", "20"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items", hasSize(20)))
                .andExpect(jsonPath("$.data.nextCursor").isNotEmpty());

        mockMvc.perform(post(POSTS_URL + "/" + postId + "/comments")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "content", "nested", "parentCommentId", oldestReplyId))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorCode").value("INVALID_COMMENT_PARENT"));

        mockMvc.perform(get(POSTS_URL + "/" + postId + "/comments/" + oldestReplyId)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorCode").value("INVALID_COMMENT_PARENT"));

        mockMvc.perform(get(POSTS_URL + "/" + postId + "/comments")
                        .header("Authorization", "Bearer " + token)
                        .param("replyLimit", "21"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void missingAndCrossPostParentsReturnSpecificErrors() throws Exception {
        String token = registerAndGetToken("parent-errors@example.com", "parent-errors");
        Long firstPostId = createPost(token, "first", "FREE", "body");
        Long secondPostId = createPost(token, "second", "FREE", "body");
        Long rootId = createComment(token, firstPostId, "root", null);

        mockMvc.perform(post(POSTS_URL + "/" + secondPostId + "/comments")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "content", "cross", "parentCommentId", rootId))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorCode").value("INVALID_COMMENT_PARENT"));

        mockMvc.perform(post(POSTS_URL + "/" + firstPostId + "/comments")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"content\":\"missing\",\"parentCommentId\":999999}"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.errorCode").value("COMMENT_NOT_FOUND"));
    }

    private Long createComment(String token, Long postId, String content, Long parentCommentId) throws Exception {
        Map<String, Object> payload = new java.util.HashMap<>();
        payload.put("content", content);
        if (parentCommentId != null) payload.put("parentCommentId", parentCommentId);
        MvcResult result = mockMvc.perform(post(POSTS_URL + "/" + postId + "/comments")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(payload)))
                .andExpect(status().isCreated())
                .andReturn();
        return readId(result);
    }

    private void assertSingleSearchResult(String token, String keyword, Long expectedPostId) throws Exception {
        mockMvc.perform(get(POSTS_URL)
                        .header("Authorization", "Bearer " + token)
                        .param("keyword", keyword))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items", hasSize(1)))
                .andExpect(jsonPath("$.data.items[0].id").value(expectedPostId));
    }

    private void assertSearchPages(String token, String sort, Long firstId, Long secondId,
                                   Long thirdId, String expectedCursor) throws Exception {
        MvcResult firstPage = mockMvc.perform(get(POSTS_URL)
                        .header("Authorization", "Bearer " + token)
                        .param("keyword", "검색")
                        .param("sort", sort)
                        .param("limit", "2"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items", hasSize(2)))
                .andExpect(jsonPath("$.data.items[0].id").value(firstId))
                .andExpect(jsonPath("$.data.items[1].id").value(secondId))
                .andExpect(jsonPath("$.data.nextCursor").value(expectedCursor))
                .andReturn();
        var data = (Map<?, ?>) objectMapper.readValue(
                firstPage.getResponse().getContentAsString(), Map.class).get("data");

        mockMvc.perform(get(POSTS_URL)
                        .header("Authorization", "Bearer " + token)
                        .param("keyword", "검색")
                        .param("sort", sort)
                        .param("cursor", data.get("nextCursor").toString())
                        .param("limit", "2"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items", hasSize(1)))
                .andExpect(jsonPath("$.data.items[0].id").value(thirdId))
                .andExpect(jsonPath("$.data.nextCursor").doesNotExist());
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

    private void uploadProfileImage(String token) throws Exception {
        MockMultipartFile file = new MockMultipartFile("file", "profile.png", "image/png",
                "profile-image-bytes".getBytes(StandardCharsets.UTF_8));
        mockMvc.perform(multipart("/api/v1/users/me/profile-image")
                        .file(file)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isCreated());
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

    private Long readUserId(String token) throws Exception {
        MvcResult result = mockMvc.perform(get("/api/v1/users/me")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andReturn();
        var data = (Map<?, ?>) objectMapper.readValue(result.getResponse().getContentAsString(), Map.class).get("data");
        return Long.parseLong(data.get("id").toString());
    }
}
