package com.formypet.auth;

import com.formypet.support.IntegrationTestSupport;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;
import java.util.Map;
import java.util.UUID;
import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@AutoConfigureMockMvc
class DeletionDataIntegrationTest extends IntegrationTestSupport {
    @Autowired MockMvc mvc;
    @Autowired JdbcTemplate jdbc;
    @Autowired ObjectMapper json;
    record Account(long id, String token) {}

    Account account() throws Exception {
        String email = UUID.randomUUID() + "@deletion.test";
        var response = mvc.perform(post("/api/v1/auth/register").contentType("application/json")
                .content(json.writeValueAsString(Map.of("email", email, "password", "Password1!", "nickname", "test"))))
                .andExpect(status().isCreated()).andReturn();
        return new Account(jdbc.queryForObject("SELECT id FROM users WHERE email=?", Long.class, email),
                json.readTree(response.getResponse().getContentAsString()).path("data").path("accessToken").asText());
    }
    long postFor(Account author) {
        jdbc.update("INSERT INTO posts(user_id,title,content) VALUES (?,'title','body')", author.id());
        return jdbc.queryForObject("SELECT MAX(id) FROM posts WHERE user_id=?", Long.class, author.id());
    }
    void erase(Account account) throws Exception {
        mvc.perform(delete("/api/v1/users/me").header("Authorization", "Bearer " + account.token())
                .contentType("application/json").content("{\"password\":\"Password1!\"}"))
                .andExpect(status().isAccepted());
    }
    @Test void preservesOtherAuthorsRepliesOnSurvivingPost() throws Exception {
        Account removed = account(), other = account();
        long post = postFor(other);
        jdbc.update("INSERT INTO post_comments(post_id,user_id,content) VALUES (?,?,'parent')", post, removed.id());
        long parent = jdbc.queryForObject("SELECT MAX(id) FROM post_comments WHERE user_id=?", Long.class, removed.id());
        jdbc.update("INSERT INTO post_comments(post_id,user_id,parent_comment_id,content) VALUES (?,?,?,'reply')", post, other.id(), parent);
        erase(removed);
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM post_comments WHERE post_id=? AND user_id=? AND parent_comment_id IS NULL", Integer.class, post, other.id())).isEqualTo(1);
        assertThat(jdbc.queryForObject("SELECT comments_count FROM posts WHERE id=?", Integer.class, post)).isEqualTo(1);
    }
    @Test void removesReportedSnapshotEvenWhenOriginalPostAlreadyGone() throws Exception {
        Account removed = account(), reporter = account();
        long post = postFor(removed);
        mvc.perform(post("/api/v1/posts/" + post + "/reports")
                .header("Authorization", "Bearer " + reporter.token()).contentType("application/json")
                .content(json.writeValueAsString(Map.of("reason", "SPAM", "detail", "report", "requestId", UUID.randomUUID().toString()))))
                .andExpect(status().isCreated());
        jdbc.update("DELETE FROM posts WHERE id=?", post);
        erase(removed);
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM support_tickets WHERE target_post_id=?", Integer.class, post)).isZero();
    }
    @Test void postDeletionRemovesPublicMediaMetadata() throws Exception {
        Account author = account();
        long post = postFor(author);
        String key = author.id() + "/community/" + UUID.randomUUID() + ".jpg";
        jdbc.update("INSERT INTO media_resources(user_id,storage_key,original_name,content_type,extension,file_size,status,visibility) VALUES (?,?,'image.jpg','image/jpeg','jpg',1,'STORED','PUBLIC')", author.id(), key);
        long media = jdbc.queryForObject("SELECT id FROM media_resources WHERE storage_key=?", Long.class, key);
        jdbc.update("INSERT INTO post_media(post_id,media_id,sort_order) VALUES (?,?,0)", post, media);
        mvc.perform(delete("/api/v1/posts/" + post).header("Authorization", "Bearer " + author.token()))
                .andExpect(status().isNoContent());
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM media_resources WHERE id=?", Integer.class, media)).isZero();
    }
}
