package com.formypet.common;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.formypet.support.IntegrationTestSupport;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.AfterEach;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import java.util.Map;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/** Real committed requests exercise the user-row lock across independent transactions. */
@AutoConfigureMockMvc
@TestPropertySource(properties = "app.media.storage-root=build/idempotency-test-storage")
class IdempotencyIntegrationTest extends IntegrationTestSupport {
    @Autowired MockMvc mvc;
    @Autowired ObjectMapper mapper;
    @Autowired JdbcTemplate jdbc;
    private final java.util.List<Long> actors = new java.util.ArrayList<>();

    @AfterEach
    void removeCommittedFixtures() {
        for (Long actor : actors) jdbc.update("DELETE FROM users WHERE id=?", actor);
    }

    @Test
    void simultaneousRecordRequestsCommitOneRecordAndOneReceipt() throws Exception {
        String token = register();
        long pet = pet(token, "pet-1");
        String url = "/api/v1/pets/" + pet + "/records";
        String body = "{\"note\":\"hello\",\"date\":\"2026-10-10\",\"typeId\":\"diary\"}";
        CountDownLatch ready = new CountDownLatch(2);
        CountDownLatch start = new CountDownLatch(1);
        try (var executor = Executors.newFixedThreadPool(2)) {
            java.util.concurrent.Callable<Long> request = () -> {
                ready.countDown();
                assertThat(start.await(10, TimeUnit.SECONDS)).isTrue();
                return json(mvc.perform(post(url).header("Authorization", "Bearer " + token)
                        .header("Idempotency-Key", "same-record").contentType(MediaType.APPLICATION_JSON)
                        .content(body)).andExpect(status().isCreated()).andReturn()).path("id").asLong();
            };
            var first = executor.submit(request);
            var second = executor.submit(request);
            assertThat(ready.await(10, TimeUnit.SECONDS)).isTrue();
            start.countDown();
            assertThat(first.get(30, TimeUnit.SECONDS)).isEqualTo(second.get(30, TimeUnit.SECONDS));
        }
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM activity_records WHERE pet_id=?", Integer.class, pet)).isEqualTo(1);
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM idempotency_requests WHERE operation='record-create' AND target=?",
                Integer.class, Long.toString(pet))).isEqualTo(1);
        // JSON object order is irrelevant to the canonical request fingerprint.
        mvc.perform(post(url).header("Authorization", "Bearer " + token).header("Idempotency-Key", "same-record")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"typeId\":\"diary\",\"date\":\"2026-10-10\",\"note\":\"hello\"}"))
                .andExpect(status().isCreated());
    }

    @Test
    void receiptsRetainOnlyIdentifiersAndReplayReadsCurrentRecord() throws Exception {
        String token = register();
        long pet = pet(token, "pet");
        String url = "/api/v1/pets/" + pet + "/records";
        String original = "{\"typeId\":\"diary\",\"date\":\"2026-10-10\",\"note\":\"private original note\"}";
        long record = json(mvc.perform(post(url).header("Authorization", "Bearer " + token)
                .header("Idempotency-Key", "record").contentType(MediaType.APPLICATION_JSON).content(original))
                .andExpect(status().isCreated()).andReturn()).path("id").asLong();
        // No response, note, post body, or file name survives resource deletion in this ledger.
        assertThat(jdbc.queryForList("SELECT column_name FROM information_schema.columns WHERE table_schema=DATABASE() AND table_name='idempotency_requests'", String.class))
                .containsExactlyInAnyOrder("user_id", "operation", "target", "request_key", "request_hash", "result_id", "created_at");
        mvc.perform(put(url + "/" + record).header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON).content("{\"note\":\"current edited note\"}"))
                .andExpect(status().isOk());
        mvc.perform(post(url).header("Authorization", "Bearer " + token)
                .header("Idempotency-Key", "record").contentType(MediaType.APPLICATION_JSON).content(original))
                .andExpect(status().isCreated()).andExpect(jsonPath("$.data.note").value("current edited note"));
        mvc.perform(delete(url + "/" + record).header("Authorization", "Bearer " + token)).andExpect(status().isNoContent());
        assertThat(jdbc.queryForObject("SELECT result_id FROM idempotency_requests WHERE operation='record-create' AND target=?", Long.class, Long.toString(pet)))
                .isEqualTo(record);
        mvc.perform(post(url).header("Authorization", "Bearer " + token)
                .header("Idempotency-Key", "record").contentType(MediaType.APPLICATION_JSON).content(original))
                .andExpect(status().isGone());
    }

    @Test
    void petReplayIsScopedByAccountAndDeletedPetCannotBeResurrected() throws Exception {
        String token = register();
        long first = pet(token, "shared-key");
        assertThat(pet(token, "shared-key")).isEqualTo(first);
        assertThat(pet(register(), "shared-key")).isNotEqualTo(first);
        mvc.perform(delete("/api/v1/pets/" + first).header("Authorization", "Bearer " + token))
                .andExpect(status().isNoContent());
        mvc.perform(post("/api/v1/pets").header("Authorization", "Bearer " + token)
                .header("Idempotency-Key", "shared-key").contentType(MediaType.APPLICATION_JSON).content(petBody()))
                .andExpect(status().isGone());
    }

    @Test
    void mediaReplayDoesNotConsumeQuotaOrAdmissionAndChangedBytesConflict() throws Exception {
        String token = register();
        long pet = pet(token, "pet");
        String url = "/api/v1/pets/" + pet + "/media";
        JsonNode first = upload(token, url, "image", image(0));
        long actor = jdbc.queryForObject("SELECT user_id FROM pets WHERE id=?", Long.class, pet);
        long used = jdbc.queryForObject("SELECT media_bytes_used FROM users WHERE id=?", Long.class, actor);
        var admissions = jdbc.queryForList("SELECT bucket_key, available_tokens, updated_at FROM request_rate_limits WHERE scope='media-upload-user'");
        assertThat(upload(token, url, "image", image(0))).isEqualTo(first);
        assertThat(jdbc.queryForObject("SELECT media_bytes_used FROM users WHERE id=?", Long.class, actor)).isEqualTo(used);
        assertThat(jdbc.queryForObject("SELECT media_items_used FROM users WHERE id=?", Integer.class, actor)).isEqualTo(1);
        assertThat(jdbc.queryForList("SELECT bucket_key, available_tokens, updated_at FROM request_rate_limits WHERE scope='media-upload-user'"))
                .isEqualTo(admissions);
        mvc.perform(multipart(url).file(image(1)).header("Authorization", "Bearer " + token)
                .header("Idempotency-Key", "image")).andExpect(status().isConflict());
        mvc.perform(delete("/api/v1/pets/" + pet).header("Authorization", "Bearer " + token)).andExpect(status().isNoContent());
        mvc.perform(multipart(url).file(image(0)).header("Authorization", "Bearer " + token)
                .header("Idempotency-Key", "image")).andExpect(status().isGone());
    }

    @Test
    void replayOfSupersededProfileUploadReturnsCurrentProfileWithoutReapplyingPhoto() throws Exception {
        String token = register();
        String url = "/api/v1/users/me/profile-image";
        JsonNode old = upload(token, url, "old", image(0));
        JsonNode current = upload(token, url, "new", image(1));
        assertThat(current.path("profileImageUrl")).isNotEqualTo(old.path("profileImageUrl"));
        assertThat(upload(token, url, "old", image(0))).isEqualTo(current);
        assertThat(json(mvc.perform(get("/api/v1/users/me").header("Authorization", "Bearer " + token))
                .andExpect(status().isOk()).andReturn())).isEqualTo(current);
    }

    @Test
    void recordMediaReplaysUntilItsRecordIsDeleted() throws Exception {
        String token = register();
        long pet = pet(token, "pet");
        String records = "/api/v1/pets/" + pet + "/records";
        long record = json(mvc.perform(post(records).header("Authorization", "Bearer " + token)
                .header("Idempotency-Key", "record").contentType(MediaType.APPLICATION_JSON)
                .content("{\"typeId\":\"diary\",\"date\":\"2026-10-10\"}"))
                .andExpect(status().isCreated()).andReturn()).path("id").asLong();
        String url = records + "/" + record + "/media";
        JsonNode first = upload(token, url, "photo", image(0));
        assertThat(upload(token, url, "photo", image(0))).isEqualTo(first);
        assertThat(upload(token, "/api/v1/pets/" + pet + "/media", "photo", image(0)).path("id"))
                .isNotEqualTo(first.path("id"));
        mvc.perform(delete(records + "/" + record).header("Authorization", "Bearer " + token))
                .andExpect(status().isNoContent());
        mvc.perform(multipart(url).file(image(0)).header("Authorization", "Bearer " + token)
                .header("Idempotency-Key", "photo")).andExpect(status().isGone());
    }

    @Test
    void communityReplayKeepsOnePostAndDeletedPostIsGone() throws Exception {
        String token = register();
        String payload = "{\"title\":\"Hello\",\"content\":\"hello\",\"category\":\"FREE\"}";
        var first = mvc.perform(multipart("/api/v1/posts").file(new MockMultipartFile("payload", "", "application/json", payload.getBytes()))
                .file(postImage(0)).file(postImage(1))
                .header("Authorization", "Bearer " + token).header("Idempotency-Key", "post"))
                .andExpect(status().isCreated()).andReturn();
        long id = json(first).path("id").asLong();
        var replay = mvc.perform(multipart("/api/v1/posts").file(new MockMultipartFile("payload", "", "application/json", payload.getBytes()))
                .file(postImage(0)).file(postImage(1))
                .header("Authorization", "Bearer " + token).header("Idempotency-Key", "post"))
                .andExpect(status().isCreated()).andReturn();
        assertThat(json(replay)).isEqualTo(json(first));
        mvc.perform(multipart("/api/v1/posts").file(new MockMultipartFile("payload", "", "application/json", payload.getBytes()))
                .file(postImage(1)).file(postImage(0))
                .header("Authorization", "Bearer " + token).header("Idempotency-Key", "post"))
                .andExpect(status().isConflict());
        mvc.perform(delete("/api/v1/posts/" + id).header("Authorization", "Bearer " + token)).andExpect(status().isNoContent());
        mvc.perform(multipart("/api/v1/posts").file(new MockMultipartFile("payload", "", "application/json", payload.getBytes()))
                .file(postImage(0)).file(postImage(1))
                .header("Authorization", "Bearer " + token).header("Idempotency-Key", "post")).andExpect(status().isGone());
    }

    @Test
    void accountDeletionRemovesReceiptsWithTheAccount() throws Exception {
        String token = register();
        long pet = pet(token, "pet");
        long actor = jdbc.queryForObject("SELECT user_id FROM pets WHERE id=?", Long.class, pet);
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM idempotency_requests WHERE user_id=?", Integer.class, actor)).isEqualTo(1);
        mvc.perform(delete("/api/v1/users/me").header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON).content("{\"password\":\"Password1!\"}"))
                .andExpect(status().isAccepted());
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM idempotency_requests WHERE user_id=?", Integer.class, actor)).isZero();
    }

    private String register() throws Exception {
        String email = UUID.randomUUID() + "@example.com";
        String token = json(mvc.perform(post("/api/v1/auth/register").contentType(MediaType.APPLICATION_JSON)
                .content(mapper.writeValueAsString(Map.of("email", email, "password", "Password1!", "nickname", "replay"))))
                .andExpect(status().isCreated()).andReturn()).path("accessToken").asText();
        actors.add(jdbc.queryForObject("SELECT id FROM users WHERE email=?", Long.class, email));
        return token;
    }

    private long pet(String token, String key) throws Exception {
        return json(mvc.perform(post("/api/v1/pets").header("Authorization", "Bearer " + token)
                .header("Idempotency-Key", key).contentType(MediaType.APPLICATION_JSON).content(petBody()))
                .andExpect(status().isCreated()).andReturn()).path("id").asLong();
    }

    private String petBody() { return "{\"name\":\"Mochi\",\"species\":\"dog\",\"birthDate\":\"2022-03-15\"}"; }

    private JsonNode upload(String token, String url, String key, MockMultipartFile image) throws Exception {
        return json(mvc.perform(multipart(url).file(image).header("Authorization", "Bearer " + token)
                .header("Idempotency-Key", key)).andExpect(status().isCreated()).andReturn());
    }

    private JsonNode json(MvcResult result) throws Exception {
        return mapper.readTree(result.getResponse().getContentAsString()).path("data");
    }

    private MockMultipartFile image(int color) throws Exception {
        var image = new java.awt.image.BufferedImage(1, 1, java.awt.image.BufferedImage.TYPE_INT_RGB);
        image.setRGB(0, 0, color);
        var bytes = new java.io.ByteArrayOutputStream();
        javax.imageio.ImageIO.write(image, "png", bytes);
        return new MockMultipartFile("file", "photo.png", "image/png", bytes.toByteArray());
    }

    private MockMultipartFile postImage(int color) throws Exception {
        return new MockMultipartFile("files", "photo.png", "image/png", image(color).getBytes());
    }
}
