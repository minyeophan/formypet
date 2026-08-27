package com.petyilgi.notification;

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
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Map;

import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.nullValue;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@AutoConfigureMockMvc
@TestPropertySource(properties = "app.media.storage-root=build/notification-test-storage")
class NotificationIntegrationTest extends IntegrationTestSupport {

    @Autowired MockMvc mockMvc;
    @Autowired ObjectMapper objectMapper;
    @Autowired UserRepository userRepository;
    @Autowired RefreshTokenRepository refreshTokenRepository;
    @Autowired JdbcTemplate jdbcTemplate;
    @Autowired NotificationService notificationService;

    @BeforeEach
    void setUp() {
        jdbcTemplate.update("DELETE FROM notifications");
        jdbcTemplate.update("UPDATE users SET profile_media_id = NULL");
        refreshTokenRepository.deleteAll();
        userRepository.deleteAll();
    }

    @Test
    void createsCommentReplyAndLikeNotificationsButSkipsSelfNotifications() throws Exception {
        String ownerToken = register("notification-owner@example.com", "owner");
        String actorToken = register("notification-actor@example.com", "actor");
        Long postId = createPost(ownerToken, "notification post");

        Long rootCommentId = createComment(actorToken, postId, "root comment", null);
        createComment(ownerToken, postId, "reply", rootCommentId);
        mockMvc.perform(post("/api/v1/posts/{postId}/like", postId)
                        .header("Authorization", bearer(actorToken)))
                .andExpect(status().isOk());

        assertEquals(2, countForEmail("notification-owner@example.com"));
        assertEquals(1, countForEmail("notification-actor@example.com"));
        assertEquals(List.of("POST_LIKE", "COMMENT"), jdbcTemplate.queryForList(
                "SELECT type FROM notifications WHERE recipient_user_id = "
                        + "(SELECT id FROM users WHERE email = ?) ORDER BY id DESC",
                String.class, "notification-owner@example.com"));
    }

    @Test
    void listsNotificationsWithCursorAndMarksOneOrAllAsRead() throws Exception {
        String token = register("notification-list@example.com", "list-user");
        Long userId = userId("notification-list@example.com");
        Long postId = createPost(token, "notification list post");
        for (int i = 1; i <= 3; i++) {
            insertNotification(userId, userId, postId, "title-" + i);
        }

        MvcResult first = mockMvc.perform(get("/api/v1/notifications")
                        .header("Authorization", bearer(token))
                        .param("limit", "2"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items", hasSize(2)))
                .andExpect(jsonPath("$.data.items[0].title").value("title-3"))
                .andExpect(jsonPath("$.data.items[1].title").value("title-2"))
                .andExpect(jsonPath("$.data.hasMore").value(true))
                .andExpect(jsonPath("$.data.unreadCount").value(3))
                .andReturn();
        String cursor = objectMapper.readTree(first.getResponse().getContentAsString())
                .at("/data/nextCursor").asText();

        mockMvc.perform(get("/api/v1/notifications")
                        .header("Authorization", bearer(token))
                        .param("cursor", cursor)
                        .param("limit", "2"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items", hasSize(1)))
                .andExpect(jsonPath("$.data.items[0].title").value("title-1"))
                .andExpect(jsonPath("$.data.hasMore").value(false));

        Long newestId = jdbcTemplate.queryForObject(
                "SELECT MAX(id) FROM notifications WHERE recipient_user_id = ?", Long.class, userId);
        mockMvc.perform(patch("/api/v1/notifications/{id}/read", newestId)
                        .header("Authorization", bearer(token)))
                .andExpect(status().isOk());
        assertEquals(1, jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM notifications WHERE recipient_user_id = ? AND read_at IS NOT NULL",
                Integer.class, userId));

        mockMvc.perform(post("/api/v1/notifications/read-all")
                        .header("Authorization", bearer(token)))
                .andExpect(status().isOk());
        assertEquals(0, jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM notifications WHERE recipient_user_id = ? AND read_at IS NULL",
                Integer.class, userId));
    }

    @Test
    void readsAndUpdatesUserNotificationSettings() throws Exception {
        String token = register("notification-settings@example.com", "settings");

        mockMvc.perform(get("/api/v1/notifications/settings")
                        .header("Authorization", bearer(token)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.enabled").value(true));

        mockMvc.perform(patch("/api/v1/notifications/settings")
                        .header("Authorization", bearer(token))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"enabled\":false}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.enabled").value(false));

        mockMvc.perform(get("/api/v1/notifications/settings")
                        .header("Authorization", bearer(token)))
                .andExpect(jsonPath("$.data.enabled").value(false));
    }

    @Test
    void rejectsMissingOrNullNotificationSetting() throws Exception {
        String token = register("notification-settings-invalid@example.com", "settings-invalid");
        mockMvc.perform(patch("/api/v1/notifications/settings")
                        .header("Authorization", bearer(token))
                        .contentType(MediaType.APPLICATION_JSON).content("{}"))
                .andExpect(status().isBadRequest());
        mockMvc.perform(patch("/api/v1/notifications/settings")
                        .header("Authorization", bearer(token))
                        .contentType(MediaType.APPLICATION_JSON).content("{\"enabled\":null}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void notificationSettingsRequireAuthentication() throws Exception {
        mockMvc.perform(get("/api/v1/notifications/settings"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void createsNotificationForTheFirstPollVoteOnly() throws Exception {
        String ownerToken = register("notification-poll-owner@example.com", "poll-owner");
        String voterToken = register("notification-poll-voter@example.com", "poll-voter");
        MvcResult post = mockMvc.perform(multipart("/api/v1/posts")
                        .file(new MockMultipartFile("payload", "", MediaType.APPLICATION_JSON_VALUE,
                                objectMapper.writeValueAsBytes(Map.of(
                                        "title", "poll notification",
                                        "category", "FREE",
                                        "content", "poll body",
                                        "poll", Map.of("question", "choose", "options", List.of("one", "two"))))))
                        .header("Authorization", bearer(ownerToken)))
                .andExpect(status().isCreated())
                .andReturn();
        var postData = objectMapper.readTree(post.getResponse().getContentAsString()).at("/data");
        Long postId = postData.at("/id").asLong();
        Long optionId = postData.at("/poll/options/0/id").asLong();

        mockMvc.perform(post("/api/v1/posts/{postId}/poll/options/{optionId}/vote", postId, optionId)
                        .header("Authorization", bearer(voterToken)))
                .andExpect(status().isOk());
        assertEquals(1, countForEmail("notification-poll-owner@example.com"));
        assertEquals("POLL_VOTE", jdbcTemplate.queryForObject(
                "SELECT type FROM notifications WHERE recipient_user_id = (SELECT id FROM users WHERE email = ?)",
                String.class, "notification-poll-owner@example.com"));
    }

    @Test
    void cleanupRemovesNotificationsOlderThanThirtyDaysOnly() throws Exception {
        String token = register("notification-cleanup@example.com", "cleanup-user");
        Long userId = userId("notification-cleanup@example.com");
        Long postId = createPost(token, "notification cleanup post");
        insertNotification(userId, userId, postId, "old");
        insertNotification(userId, userId, postId, "recent");
        jdbcTemplate.update("UPDATE notifications SET created_at = DATE_SUB(CURRENT_TIMESTAMP(6), INTERVAL 31 DAY) WHERE title = 'old'");

        assertEquals(1, notificationService.cleanup());
        mockMvc.perform(get("/api/v1/notifications")
                        .header("Authorization", bearer(token)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items", hasSize(1)))
                .andExpect(jsonPath("$.data.items[0].title").value("recent"));
    }

    @Test
    void reminderInsertIsIdempotentButAllowsDifferentRecipients() throws Exception {
        register("reminder-owner@example.com", "owner");
        register("reminder-other@example.com", "other");
        Long owner = userId("reminder-owner@example.com");
        Long other = userId("reminder-other@example.com");
        LocalDateTime scheduled = LocalDateTime.now().plusMinutes(10).truncatedTo(ChronoUnit.MICROS);

        notificationService.createReminder(owner, NotificationType.ROUTINE_REMINDER,
                "ROUTINE", 77L, scheduled, "루틴 알림", "물 마실 시간입니다.");
        notificationService.createReminder(owner, NotificationType.ROUTINE_REMINDER,
                "ROUTINE", 77L, scheduled, "루틴 알림", "물 마실 시간입니다.");
        notificationService.createReminder(other, NotificationType.ROUTINE_REMINDER,
                "ROUTINE", 77L, scheduled, "루틴 알림", "물 마실 시간입니다.");

        assertEquals(2, jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM notifications WHERE source_type='ROUTINE' AND source_id=77", Integer.class));
    }

    @Test
    void deletingPendingRemindersKeepsReadAndPastReminders() throws Exception {
        register("reminder-cleanup@example.com", "cleanup");
        Long userId = userId("reminder-cleanup@example.com");
        LocalDateTime now = LocalDateTime.now().truncatedTo(ChronoUnit.MICROS);
        notificationService.createReminder(userId, NotificationType.CARE_SCHEDULE_REMINDER,
                "CARE_SCHEDULE", 88L, now.plusMinutes(30), "future", "future");
        notificationService.createReminder(userId, NotificationType.CARE_SCHEDULE_REMINDER,
                "CARE_SCHEDULE", 88L, now.minusMinutes(30), "past", "past");
        notificationService.createReminder(userId, NotificationType.CARE_SCHEDULE_REMINDER,
                "CARE_SCHEDULE", 88L, now.plusMinutes(60), "read", "read");
        jdbcTemplate.update("UPDATE notifications SET read_at=? WHERE title='read'", now);

        assertEquals(1, notificationService.deletePendingReminders("CARE_SCHEDULE", 88L));
        assertEquals(2, jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM notifications WHERE source_type='CARE_SCHEDULE' AND source_id=88", Integer.class));
    }

    @Test
    void reminderWithNullSocialFieldsIsReturnedByNotificationFeed() throws Exception {
        String token = register("reminder-feed@example.com", "feed");
        Long userId = userId("reminder-feed@example.com");
        notificationService.createReminder(userId, NotificationType.ROUTINE_REMINDER,
                "ROUTINE", 99L, LocalDateTime.now(), "루틴 알림", "초코님의 물 먹기 시간입니다.");

        mockMvc.perform(get("/api/v1/notifications")
                        .header("Authorization", bearer(token)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items[0].actorUserId").value(nullValue()))
                .andExpect(jsonPath("$.data.items[0].postId").value(nullValue()))
                .andExpect(jsonPath("$.data.items[0].sourceType").value("ROUTINE"))
                .andExpect(jsonPath("$.data.items[0].sourceId").value(99));
    }

    private String register(String email, String nickname) throws Exception {
        MvcResult result = mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "email", email,
                                "password", "Password1!",
                                "nickname", nickname))))
                .andExpect(status().isCreated())
                .andReturn();
        return objectMapper.readTree(result.getResponse().getContentAsString())
                .at("/data/accessToken").asText();
    }

    private Long createPost(String token, String title) throws Exception {
        MvcResult result = mockMvc.perform(multipart("/api/v1/posts")
                        .file(new MockMultipartFile("payload", "", MediaType.APPLICATION_JSON_VALUE,
                                objectMapper.writeValueAsBytes(Map.of(
                                        "title", title,
                                        "category", "FREE",
                                        "content", "notification body"))))
                        .header("Authorization", bearer(token)))
                .andExpect(status().isCreated())
                .andReturn();
        return objectMapper.readTree(result.getResponse().getContentAsString()).at("/data/id").asLong();
    }

    private Long createComment(String token, Long postId, String content, Long parentId) throws Exception {
        Map<String, Object> body = new java.util.HashMap<>();
        body.put("content", content);
        if (parentId != null) body.put("parentCommentId", parentId);
        MvcResult result = mockMvc.perform(post("/api/v1/posts/{postId}/comments", postId)
                        .header("Authorization", bearer(token))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsBytes(body)))
                .andExpect(status().isCreated())
                .andReturn();
        return objectMapper.readTree(result.getResponse().getContentAsString()).at("/data/id").asLong();
    }

    private void insertNotification(Long userId, Long actorId, Long postId, String title) {
        jdbcTemplate.update("""
                INSERT INTO notifications
                    (recipient_user_id, actor_user_id, actor_nickname, type, post_id, title, body, created_at)
                VALUES (?, ?, ?, 'COMMENT', ?, ?, ?, ?)
                """, userId, actorId, "actor", postId, title, "body", LocalDateTime.now());
    }

    private Long userId(String email) {
        return jdbcTemplate.queryForObject("SELECT id FROM users WHERE email = ?", Long.class, email);
    }

    private int countForEmail(String email) {
        return jdbcTemplate.queryForObject("""
                SELECT COUNT(*) FROM notifications
                WHERE recipient_user_id = (SELECT id FROM users WHERE email = ?)
                """, Integer.class, email);
    }

    private String bearer(String token) {
        return "Bearer " + token;
    }
}
