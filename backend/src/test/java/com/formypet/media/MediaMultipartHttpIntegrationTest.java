package com.formypet.media;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.formypet.media.storage.MediaStorage;
import com.formypet.support.IntegrationTestSupport;
import org.apache.hc.client5.http.config.RequestConfig;
import org.apache.hc.client5.http.impl.classic.HttpClients;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.http.client.ClientHttpResponse;
import org.springframework.http.client.HttpComponentsClientHttpRequestFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.TestPropertySource;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.web.client.DefaultResponseErrorHandler;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.client.ResourceAccessException;

import java.util.Arrays;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

/** Exercises servlet multipart limits over HTTP; MockMvc does not enforce these limits. */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@TestPropertySource(properties = "app.media.storage-root=build/multipart-http-test-storage")
class MediaMultipartHttpIntegrationTest extends IntegrationTestSupport {
    private static final int MAX_IMAGE_BYTES = 5 * 1024 * 1024;
    @LocalServerPort int port;
    @Autowired ObjectMapper mapper;
    @Autowired JdbcTemplate jdbc;
    @Autowired MediaStorage storage;
    private Long actorId;

    @AfterEach
    void removeCommittedFixtures() throws Exception {
        if (actorId == null) return;
        var keys = jdbc.queryForList("SELECT storage_key FROM media_resources WHERE user_id=?", String.class, actorId);
        jdbc.update("DELETE FROM users WHERE id=?", actorId);
        for (String key : keys) {
            storage.delete(key);
            jdbc.update("DELETE FROM media_storage_attempts WHERE storage_key=?", key);
            jdbc.update("DELETE FROM media_cleanup_queue WHERE storage_key=?", key);
        }
    }

    @Test
    void servletAcceptsFiveMaximumImagesAndRejectsOversizedEnvelopeAndSingleFile() throws Exception {
        // Known content length and Expect:100-continue let the server reject oversized
        // requests before the client streams their body, preserving the actual HTTP413.
        try (var client = HttpClients.custom().setDefaultRequestConfig(
                RequestConfig.custom().setExpectContinueEnabled(true).build()).build()) {
            var http = new RestTemplate(new HttpComponentsClientHttpRequestFactory(client));
            http.setErrorHandler(new DefaultResponseErrorHandler() {
                @Override public boolean hasError(ClientHttpResponse response) { return false; }
            });
            String email = UUID.randomUUID() + "@example.com";
            var registration = http.postForEntity(url("/api/v1/auth/register"),
                    Map.of("email", email, "password", "Password1!", "nickname", "httplimits"), String.class);
            assertThat(registration.getStatusCode()).isEqualTo(HttpStatus.CREATED);
            String token = mapper.readTree(registration.getBody()).path("data").path("accessToken").asText();
            actorId = jdbc.queryForObject("SELECT id FROM users WHERE email=?", Long.class, email);

            byte[] image = maximumImage();
            var accepted = upload(http, token, image, 5);
            assertThat(accepted.getStatusCode()).isEqualTo(HttpStatus.CREATED);
            assertThat(jdbc.queryForObject("SELECT media_bytes_used FROM users WHERE id=?", Long.class, actorId))
                    .isEqualTo(5L * MAX_IMAGE_BYTES);
            assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM media_resources WHERE user_id=?", Integer.class, actorId))
                    .isEqualTo(5);

            // Tomcat can reset the connection while rejecting a single part over its
            // per-file limit, before a structured 413 reaches the client.
            org.assertj.core.api.Assertions.assertThatThrownBy(
                    () -> upload(http, token, Arrays.copyOf(image, MAX_IMAGE_BYTES + 1), 1))
                    .isInstanceOf(ResourceAccessException.class);
            // Tomcat may close the connection while rejecting a body larger than the
            // request envelope. Either way, the parser rejects before controller writes.
            org.assertj.core.api.Assertions.assertThatThrownBy(() -> upload(http, token, image, 6))
                    .isInstanceOf(ResourceAccessException.class);
            assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM posts WHERE user_id=?", Integer.class, actorId)).isEqualTo(1);
            assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM media_resources WHERE user_id=?", Integer.class, actorId)).isEqualTo(5);
            assertThat(jdbc.queryForObject("SELECT media_bytes_used FROM users WHERE id=?", Long.class, actorId))
                    .isEqualTo(5L * MAX_IMAGE_BYTES);
            assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM idempotency_requests WHERE user_id=?", Integer.class, actorId))
                    .isEqualTo(1);
        }
    }

    private ResponseEntity<String> upload(RestTemplate http, String token, byte[] bytes, int count) {
        var parts = new LinkedMultiValueMap<String, Object>();
        HttpHeaders payloadHeaders = new HttpHeaders();
        payloadHeaders.setContentType(MediaType.APPLICATION_JSON);
        parts.add("payload", new HttpEntity<>("{\"title\":\"Limits\",\"content\":\"five photos\",\"category\":\"FREE\"}", payloadHeaders));
        for (int i = 0; i < count; i++) {
            final String filename = "photo-" + i + ".png";
            var resource = new ByteArrayResource(bytes) {
                @Override public String getFilename() { return filename; }
            };
            HttpHeaders imageHeaders = new HttpHeaders();
            imageHeaders.setContentType(MediaType.IMAGE_PNG);
            parts.add("files", new HttpEntity<>(resource, imageHeaders));
        }
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.MULTIPART_FORM_DATA);
        headers.setBearerAuth(token);
        headers.set("Idempotency-Key", UUID.randomUUID().toString());
        return http.exchange(url("/api/v1/posts"), HttpMethod.POST, new HttpEntity<>(parts, headers), String.class);
    }

    private String url(String path) { return "http://localhost:" + port + path; }

    private byte[] maximumImage() throws Exception {
        var source = new java.awt.image.BufferedImage(1, 1, java.awt.image.BufferedImage.TYPE_INT_RGB);
        var output = new java.io.ByteArrayOutputStream();
        javax.imageio.ImageIO.write(source, "png", output);
        return Arrays.copyOf(output.toByteArray(), MAX_IMAGE_BYTES);
    }
}
