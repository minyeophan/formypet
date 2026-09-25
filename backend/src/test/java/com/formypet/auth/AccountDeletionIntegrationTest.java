package com.formypet.auth;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.formypet.auth.client.KakaoUserClient;
import com.formypet.auth.client.KakaoUserInfo;
import com.formypet.support.IntegrationTestSupport;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@AutoConfigureMockMvc
class AccountDeletionIntegrationTest extends IntegrationTestSupport {
    private static final String PASSWORD = "Password1!";
    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;
    @Autowired JdbcTemplate jdbc;
    @MockitoBean KakaoUserClient kakao;

    @BeforeEach
    void clean() {
        jdbc.update("DELETE FROM account_deletion_jobs");
        jdbc.update("DELETE FROM support_mail_outbox");
        jdbc.update("DELETE FROM support_tickets");
        jdbc.update("DELETE FROM refresh_tokens");
        jdbc.update("DELETE FROM users");
    }

    @Test
    void localAccountRequiresPasswordAndDeletesItsRowsAndInvalidatesAccessToken() throws Exception {
        String email = UUID.randomUUID() + "@example.test";
        String token = register(email);
        long userId = jdbc.queryForObject("SELECT id FROM users WHERE email=?", Long.class, email);
        String refresh = jdbc.queryForObject("SELECT token FROM refresh_tokens WHERE user_id=?", String.class, userId);

        mvc.perform(delete("/api/v1/users/me")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("password", "wrong-password"))))
                .andExpect(status().isUnauthorized());
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM users WHERE id=?", Integer.class, userId)).isEqualTo(1);

        mvc.perform(delete("/api/v1/users/me")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("password", PASSWORD))))
                .andExpect(status().isAccepted())
                .andExpect(jsonPath("$.data.status").value("ACCEPTED"));

        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM users WHERE id=?", Integer.class, userId)).isZero();
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM refresh_tokens WHERE token=?", Integer.class, refresh)).isZero();
        mvc.perform(get("/api/v1/users/me").header("Authorization", "Bearer " + token))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void localDeletionRemovesCommunityAndMediaDataAndRecalculatesOtherAuthorsCounters() throws Exception {
        String email = UUID.randomUUID() + "@example.test";
        String token = register(email);
        long userId = jdbc.queryForObject("SELECT id FROM users WHERE email=?", Long.class, email);
        String otherEmail = UUID.randomUUID() + "@example.test";
        jdbc.update("INSERT INTO users(email,password_hash,nickname,registration_source) VALUES (?, 'hash', 'other', 'LOCAL')", otherEmail);
        long otherUser = jdbc.queryForObject("SELECT id FROM users WHERE email=?", Long.class, otherEmail);
        jdbc.update("INSERT INTO posts(user_id,title,category,content,likes_count,comments_count) VALUES (?,?,?,?,1,1)",
                otherUser, "Other post", "FREE", "post body");
        long otherPost = jdbc.queryForObject("SELECT id FROM posts WHERE user_id=?", Long.class, otherUser);
        jdbc.update("INSERT INTO post_comments(post_id,user_id,content) VALUES (?,?,?)", otherPost, userId, "comment");
        jdbc.update("INSERT INTO post_likes(user_id,post_id) VALUES (?,?)", userId, otherPost);
        jdbc.update("INSERT INTO post_polls(post_id,question) VALUES (?,?)", otherPost, "question");
        long poll = jdbc.queryForObject("SELECT id FROM post_polls WHERE post_id=?", Long.class, otherPost);
        jdbc.update("INSERT INTO post_poll_options(poll_id,label,votes_count,sort_order) VALUES (?,?,1,0)", poll, "choice");
        long option = jdbc.queryForObject("SELECT id FROM post_poll_options WHERE poll_id=?", Long.class, poll);
        jdbc.update("INSERT INTO post_poll_votes(poll_id,user_id,option_id) VALUES (?,?,?)", poll, userId, option);
        jdbc.update("""
                INSERT INTO media_resources(user_id,storage_key,original_name,content_type,extension,file_size,status,visibility,created_at)
                VALUES (?, '7/profile/portrait.jpg', 'portrait.jpg', 'image/jpeg', 'jpg', 3, 'STORED', 'PRIVATE', UTC_TIMESTAMP(6))
                """, userId);
        jdbc.update("""
                INSERT INTO support_tickets(requester_user_id,kind,request_id,payload_hash,category,title,content,created_at)
                VALUES (?,'INQUIRY','delete-test',REPEAT('a',64),'BUG','title','sensitive body',UTC_TIMESTAMP(6))
                """, userId);
        long ticket = jdbc.queryForObject("SELECT id FROM support_tickets WHERE requester_user_id=?", Long.class, userId);
        jdbc.update("INSERT INTO support_mail_outbox(ticket_id,next_attempt_at) VALUES (?,UTC_TIMESTAMP(6))", ticket);

        mvc.perform(delete("/api/v1/users/me")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("password", PASSWORD))))
                .andExpect(status().isAccepted());

        assertThat(jdbc.queryForObject("SELECT likes_count FROM posts WHERE id=?", Integer.class, otherPost)).isZero();
        assertThat(jdbc.queryForObject("SELECT comments_count FROM posts WHERE id=?", Integer.class, otherPost)).isZero();
        assertThat(jdbc.queryForObject("SELECT votes_count FROM post_poll_options WHERE id=?", Integer.class, option)).isZero();
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM media_cleanup_queue WHERE storage_key='7/profile/portrait.jpg'", Integer.class)).isEqualTo(1);
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM media_resources WHERE user_id=?", Integer.class, userId)).isZero();
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM support_tickets WHERE requester_user_id=?", Integer.class, userId)).isZero();
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM support_mail_outbox WHERE ticket_id=?", Integer.class, ticket)).isZero();
    }

    @Test
    void kakaoAccountDeletionRequiresMatchingKakaoIdentityAndQueuesUnlink() throws Exception {
        String providerId = Long.toString(System.nanoTime());
        when(kakao.fetchUser("kakao-login-token"))
                .thenReturn(new KakaoUserInfo(providerId, null, false, "Kakao"));
        MvcResult login = mvc.perform(post("/api/v1/auth/kakao")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("accessToken", "kakao-login-token"))))
                .andExpect(status().isOk()).andReturn();
        String token = json.readTree(login.getResponse().getContentAsString())
                .path("data").path("accessToken").asText();
        when(kakao.fetchUser("kakao-reauth-token"))
                .thenReturn(new KakaoUserInfo(providerId, null, false, "Kakao"));

        mvc.perform(delete("/api/v1/users/me")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("kakaoAccessToken", "kakao-reauth-token"))))
                .andExpect(status().isAccepted());

        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM oauth_accounts WHERE provider_user_id=?", Integer.class, providerId)).isZero();
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM account_deletion_jobs WHERE provider_user_id=?", Integer.class, providerId)).isEqualTo(1);
    }

    private String register(String email) throws Exception {
        MvcResult result = mvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of(
                                "email", email, "password", PASSWORD, "nickname", "test"))))
                .andExpect(status().isCreated()).andReturn();
        return json.readTree(result.getResponse().getContentAsString())
                .path("data").path("accessToken").asText();
    }
}
