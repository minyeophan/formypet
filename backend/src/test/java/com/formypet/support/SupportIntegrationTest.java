package com.formypet.support;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@AutoConfigureMockMvc
class SupportIntegrationTest extends IntegrationTestSupport {
    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;
    @Autowired JdbcTemplate jdbc;
    @Autowired SupportService service;
    @Autowired SupportMailWorker worker;
    @MockitoBean SupportMailTransport transport;
    String email;
    long uid;
    long postId;

    @BeforeEach
    void setup() {
        jdbc.update("DELETE FROM support_mail_outbox");
        jdbc.update("DELETE FROM support_tickets");
        email = UUID.randomUUID() + "@example.test";
        uid = user(email);
        long author = user(UUID.randomUUID() + "@example.test");
        jdbc.update("INSERT INTO posts(user_id,title,content) VALUES (?,?,?)", author, "신고 대상", "원본 내용");
        postId = jdbc.queryForObject("SELECT id FROM posts WHERE user_id=?", Long.class, author);
    }

    @Test void inquiryPersistsReceiptAndOutboxAndUsesReplyTo() throws Exception {
        var result = mvc.perform(authPost("/api/v1/inquiries", inquiry("inquiry-1")))
                .andExpect(status().isCreated()).andExpect(jsonPath("$.data.id").isString()).andReturn();
        var data = json.readTree(result.getResponse().getContentAsString()).get("data");
        assertNotNull(OffsetDateTime.parse(data.get("receivedAt").asText()));
        assertEquals(1, count("support_tickets"));
        assertEquals(1, count("support_mail_outbox"));
        verifyNoInteractions(transport);
        assertTrue(worker.processOne());
        verify(transport).send(contains("[문의 #"), contains("문의 본문"), eq("reply@example.test"));
        assertEquals("SENT", state());
        assertFalse(worker.processOne());
    }

    @Test void inquiryRetryReturnsSameReceiptAndDifferentPayloadConflicts() throws Exception {
        String first = mvc.perform(authPost("/api/v1/inquiries", inquiry("same"))).andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        String second = mvc.perform(authPost("/api/v1/inquiries", inquiry("same"))).andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        assertEquals(json.readTree(first).get("data"), json.readTree(second).get("data"));
        var changed = new java.util.HashMap<>(inquiry("same"));
        changed.put("body", "다른 본문");
        mvc.perform(authPost("/api/v1/inquiries", changed)).andExpect(status().isConflict());
        assertEquals(1, count("support_mail_outbox"));
    }

    @Test void authenticationAndInputValidation() throws Exception {
        mvc.perform(post("/api/v1/inquiries").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(inquiry("a"))))
                .andExpect(status().isUnauthorized());
        for (var invalid : List.of(Map.entry("type", "INVALID"), Map.entry("title", " "),
                Map.entry("title", "a".repeat(101)), Map.entry("body", "a".repeat(3001)),
                Map.entry("replyEmail", "no-address"), Map.entry("replyEmail", "x@example.test\r\nBcc: other@example.test"),
                Map.entry("title", "hello\nBcc: other@example.test"), Map.entry("requestId", "x".repeat(65)))) {
            var request = new java.util.HashMap<>(inquiry("validation"));
            request.put(invalid.getKey(), invalid.getValue());
            mvc.perform(authPost("/api/v1/inquiries", request)).andExpect(status().isBadRequest());
        }
        assertEquals(0, count("support_tickets"));
    }

    @Test void reportDuplicateSnapshotAndRetryAfterPostDeletion() throws Exception {
        String path = "/api/v1/posts/" + postId + "/reports";
        var request = Map.of("reason", "SPAM", "detail", "광고", "requestId", "report-1");
        mvc.perform(authPost(path, request)).andExpect(status().isCreated());
        mvc.perform(authPost(path, Map.of("reason", "SPAM", "detail", "광고", "requestId", "report-2")))
                .andExpect(status().isConflict());
        mvc.perform(authPost(path, Map.of("reason", "ABUSE", "detail", "다른 내용", "requestId", "report-1")))
                .andExpect(status().isConflict());
        jdbc.update("DELETE FROM posts WHERE id=?", postId);
        mvc.perform(authPost(path, request)).andExpect(status().isCreated());
        assertTrue(jdbc.queryForObject("SELECT target_snapshot FROM support_tickets", String.class).contains("원본 내용"));
        assertEquals(1, count("support_mail_outbox"));
        worker.processOne();
        verify(transport).send(contains("[신고 #"), contains("원본 내용"), isNull());
    }

    @Test void reportRejectsSelfMissingAndInvalidReasons() throws Exception {
        String path = "/api/v1/posts/" + postId + "/reports";
        for (var request : List.of(
                Map.of("reason", "INVALID", "detail", "", "requestId", "r1"),
                Map.of("reason", "OTHER", "detail", " ", "requestId", "r2"),
                Map.of("reason", "SPAM", "detail", "a".repeat(501), "requestId", "r3"))) {
            mvc.perform(authPost(path, request)).andExpect(status().isBadRequest());
        }
        var valid = Map.of("reason", "OTHER", "detail", "신고 내용", "requestId", "r4");
        mvc.perform(authPost("/api/v1/posts/9223372036854775807/reports", valid)).andExpect(status().isNotFound());
        jdbc.update("UPDATE posts SET user_id=? WHERE id=?", uid, postId);
        mvc.perform(authPost(path, valid)).andExpect(status().isForbidden());
        assertEquals(0, count("support_tickets"));
    }

    @Test void concurrentSameRequestProducesOneReceipt() throws Exception {
        var request = new SupportController.InquiryRequest("BUG", "reply@example.test", "제목", "본문", "concurrent");
        var start = new CountDownLatch(1);
        try (var executor = Executors.newFixedThreadPool(2)) {
            var first = executor.submit(() -> { start.await(); return service.inquiry(email, request); });
            var second = executor.submit(() -> { start.await(); return service.inquiry(email, request); });
            start.countDown();
            assertEquals(first.get(10, TimeUnit.SECONDS), second.get(10, TimeUnit.SECONDS));
        }
        assertEquals(1, count("support_tickets"));
        assertEquals(1, count("support_mail_outbox"));
    }

    @Test void concurrentReportRetriesReturnSameReceipt() throws Exception {
        var request = new SupportController.ReportRequest("SPAM", "광고", "same-report");
        var start = new CountDownLatch(1);
        try (var executor = Executors.newFixedThreadPool(2)) {
            var first = executor.submit(() -> { start.await(); return service.report(email, postId, request); });
            var second = executor.submit(() -> { start.await(); return service.report(email, postId, request); });
            start.countDown();
            assertEquals(first.get(10, TimeUnit.SECONDS), second.get(10, TimeUnit.SECONDS));
        }
        assertEquals(1, count("support_tickets"));
        assertEquals(1, count("support_mail_outbox"));
    }

    @Test void concurrentDifferentRequestIdsCannotReportSamePostTwice() throws Exception {
        var start = new CountDownLatch(1);
        try (var executor = Executors.newFixedThreadPool(2)) {
            var first = executor.submit(() -> { start.await(); return reportOutcome("first-report"); });
            var second = executor.submit(() -> { start.await(); return reportOutcome("second-report"); });
            start.countDown();
            var outcomes = List.of(first.get(10, TimeUnit.SECONDS), second.get(10, TimeUnit.SECONDS));
            assertEquals(1, outcomes.stream().filter("accepted"::equals).count());
            assertEquals(1, outcomes.stream().filter("POST_ALREADY_REPORTED"::equals).count());
        }
        assertEquals(1, count("support_tickets"));
        assertEquals(1, count("support_mail_outbox"));
    }

    @Test void outboxInsertFailureRollsBackTicketAndAllowsRetry() {
        var request = new SupportController.InquiryRequest("BUG", "reply@example.test", "제목", "본문", "atomic");
        jdbc.execute("""
                CREATE TRIGGER support_test_outbox_failure BEFORE INSERT ON support_mail_outbox
                FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='test outbox failure'
                """);
        try {
            assertThrows(org.springframework.dao.DataAccessException.class, () -> service.inquiry(email, request));
            assertEquals(0, count("support_tickets"));
            assertEquals(0, count("support_mail_outbox"));
        } finally { jdbc.execute("DROP TRIGGER support_test_outbox_failure"); }
        service.inquiry(email, request);
        assertEquals(1, count("support_tickets"));
        assertEquals(1, count("support_mail_outbox"));
    }

    private String reportOutcome(String requestId) {
        try {
            service.report(email, postId, new SupportController.ReportRequest("SPAM", "광고", requestId));
            return "accepted";
        } catch (com.formypet.common.exception.ApiException conflict) {
            assertEquals(org.springframework.http.HttpStatus.CONFLICT, conflict.status());
            return conflict.errorCode();
        }
    }

    @Test void mailFailureRetainsTicketAndRetriesThenSucceeds() throws Exception {
        service.inquiry(email, new SupportController.InquiryRequest("BUG", "reply@example.test", "제목", "본문", "retry"));
        doThrow(new IllegalStateException("sensitive SMTP diagnostic")).doNothing().when(transport).send(anyString(), anyString(), anyString());
        worker.processOne();
        assertEquals("PENDING", state());
        assertEquals(1, count("support_tickets"));
        assertEquals("IllegalStateException", jdbc.queryForObject("SELECT last_error FROM support_mail_outbox", String.class));
        assertFalse(worker.processOne());
        due();
        worker.processOne();
        assertEquals("SENT", state());
        verify(transport, times(2)).send(anyString(), anyString(), anyString());
    }

    @Test void retryScheduleAndExhaustionArePersisted() throws Exception {
        service.inquiry(email, new SupportController.InquiryRequest("BUG", "reply@example.test", "제목", "본문", "fail"));
        doThrow(new IllegalStateException()).when(transport).send(anyString(), anyString(), anyString());
        int[] delays = {60, 300, 1800, 7200};
        for (int attempt = 0; attempt < 5; attempt++) {
            due();
            assertTrue(worker.processOne());
            assertEquals(attempt + 1, jdbc.queryForObject("SELECT attempts FROM support_mail_outbox", Integer.class));
            if (attempt < 4) {
                int seconds = jdbc.queryForObject("SELECT TIMESTAMPDIFF(SECOND,UTC_TIMESTAMP(),next_attempt_at) FROM support_mail_outbox", Integer.class);
                assertTrue(seconds >= delays[attempt] - 5 && seconds <= delays[attempt] + 1);
            }
        }
        assertEquals("FAILED", state());
        assertFalse(worker.processOne());
        assertEquals(1, count("support_tickets"));
    }

    @Test void expiredLeaseIsRecoveredButActiveLeaseIsNotStolen() {
        service.inquiry(email, new SupportController.InquiryRequest("BUG", "reply@example.test", "제목", "본문", "lease"));
        jdbc.update("UPDATE support_mail_outbox SET status='PROCESSING',attempts=1,lease_until=DATE_ADD(UTC_TIMESTAMP(), INTERVAL 5 MINUTE),claim_token='old'");
        assertFalse(worker.processOne());
        jdbc.update("UPDATE support_mail_outbox SET lease_until=DATE_SUB(UTC_TIMESTAMP(), INTERVAL 1 MINUTE)");
        assertTrue(worker.processOne());
        assertEquals("SENT", state());
        assertEquals(2, jdbc.queryForObject("SELECT attempts FROM support_mail_outbox", Integer.class));
    }

    @Test void finalExpiredLeaseBecomesFailed() {
        service.inquiry(email, new SupportController.InquiryRequest("BUG", "reply@example.test", "제목", "본문", "final-lease"));
        jdbc.update("UPDATE support_mail_outbox SET status='PROCESSING',attempts=5,lease_until=DATE_SUB(UTC_TIMESTAMP(), INTERVAL 1 MINUTE)");
        assertFalse(worker.processOne());
        assertEquals("FAILED", state());
        verifyNoInteractions(transport);
    }

    @Test void concurrentWorkersDoNotSendAnActiveClaimTwice() throws Exception {
        service.inquiry(email, new SupportController.InquiryRequest("BUG", "reply@example.test", "제목", "본문", "worker-race"));
        var started = new CountDownLatch(1);
        var release = new CountDownLatch(1);
        doAnswer(invocation -> {
            started.countDown();
            assertTrue(release.await(10, TimeUnit.SECONDS));
            return null;
        }).when(transport).send(anyString(), anyString(), anyString());
        try (var executor = Executors.newSingleThreadExecutor()) {
            var pending = executor.submit(worker::processOne);
            try {
                assertTrue(started.await(10, TimeUnit.SECONDS));
                assertFalse(worker.processOne());
            } finally { release.countDown(); }
            assertTrue(pending.get(10, TimeUnit.SECONDS));
        }
        assertEquals("SENT", state());
        verify(transport, times(1)).send(anyString(), anyString(), anyString());
    }

    @Test void expiredWorkerCannotOverwriteNewClaim() throws Exception {
        service.inquiry(email, new SupportController.InquiryRequest("BUG", "reply@example.test", "제목", "본문", "worker-fence"));
        doAnswer(invocation -> {
            jdbc.update("UPDATE support_mail_outbox SET claim_token='new-worker'");
            return null;
        }).when(transport).send(anyString(), anyString(), anyString());
        worker.processOne();
        assertEquals("PROCESSING", state());
        assertEquals("new-worker", jdbc.queryForObject("SELECT claim_token FROM support_mail_outbox", String.class));
    }

    private long user(String address) {
        jdbc.update("INSERT INTO users(email,password_hash,nickname) VALUES (?,'not-a-real-password','테스트')", address);
        return jdbc.queryForObject("SELECT id FROM users WHERE email=?", Long.class, address);
    }
    private Map<String,String> inquiry(String key) {
        return Map.of("type", "BUG", "replyEmail", "reply@example.test", "title", "문의 제목", "body", "문의 본문", "requestId", key);
    }
    private MockHttpServletRequestBuilder authPost(String path, Object data) throws Exception {
        return post(path).with(authentication(new UsernamePasswordAuthenticationToken(email, null, List.of())))
                .contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(data));
    }
    private int count(String table) { return jdbc.queryForObject("SELECT COUNT(*) FROM " + table, Integer.class); }
    private String state() { return jdbc.queryForObject("SELECT status FROM support_mail_outbox", String.class); }
    private void due() { jdbc.update("UPDATE support_mail_outbox SET next_attempt_at=DATE_SUB(UTC_TIMESTAMP(), INTERVAL 1 MINUTE)"); }
}
