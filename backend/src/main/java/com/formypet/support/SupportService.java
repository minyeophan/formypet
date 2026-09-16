package com.formypet.support;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.formypet.common.exception.ApiException;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.sql.Statement;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.HexFormat;
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class SupportService {
    private final JdbcTemplate jdbc;
    private final ObjectMapper json;

    public record Receipt(String id, OffsetDateTime receivedAt) {}

    @Transactional
    public Receipt inquiry(String email, SupportController.InquiryRequest request) {
        long uid = lockUser(email);
        String title = request.title().trim();
        String body = request.body().trim();
        String reply = request.replyEmail().trim();
        String hash = hash(List.of(request.type(), title, body, reply));
        Receipt existing = existing(uid, "INQUIRY", request.requestId(), hash);
        if (existing != null) return existing;
        return insert(uid, "INQUIRY", request.requestId(), hash, request.type(), title, body, reply, null, null);
    }

    @Transactional
    public Receipt report(String email, long postId, SupportController.ReportRequest request) {
        long uid = lockUser(email);
        String detail = request.detail() == null ? "" : request.detail().trim();
        if (request.reason().equals("OTHER") && detail.isEmpty()) {
            throw error(HttpStatus.BAD_REQUEST, "REPORT_DETAIL_REQUIRED", "기타 사유의 상세 내용을 입력해 주세요.");
        }
        String hash = hash(List.of(postId, request.reason(), detail));
        // A successfully accepted request stays retryable after its target is deleted.
        Receipt existing = existing(uid, "POST_REPORT", request.requestId(), hash);
        if (existing != null) return existing;
        if (jdbc.queryForObject("SELECT COUNT(*) FROM support_tickets WHERE requester_user_id=? AND target_post_id=?",
                Integer.class, uid, postId) > 0) {
            throw error(HttpStatus.CONFLICT, "POST_ALREADY_REPORTED", "이미 신고한 게시글이에요.");
        }
        var posts = jdbc.queryForList("""
                SELECT p.user_id, p.title, p.content, u.nickname
                FROM posts p JOIN users u ON u.id=p.user_id WHERE p.id=?
                """, postId);
        if (posts.isEmpty()) throw error(HttpStatus.NOT_FOUND, "POST_NOT_FOUND", "게시글을 찾을 수 없어요.");
        Map<String, Object> post = posts.getFirst();
        if (((Number) post.get("user_id")).longValue() == uid) {
            throw error(HttpStatus.FORBIDDEN, "SELF_REPORT_FORBIDDEN", "본인 게시글은 신고할 수 없어요.");
        }
        return insert(uid, "POST_REPORT", request.requestId(), hash, request.reason(), "게시글 신고", detail,
                null, postId, encode(post));
    }

    private long lockUser(String email) {
        // Serializes this user's submissions, including concurrent retries with different request IDs.
        var ids = jdbc.queryForList("SELECT id FROM users WHERE email=? FOR UPDATE", Long.class, email);
        if (ids.isEmpty()) throw error(HttpStatus.UNAUTHORIZED, "UNAUTHORIZED", "로그인이 필요해요.");
        return ids.getFirst();
    }

    private Receipt existing(long uid, String kind, String requestId, String hash) {
        return jdbc.query("SELECT id,payload_hash,created_at FROM support_tickets WHERE requester_user_id=? AND kind=? AND request_id=?",
                (rs, row) -> {
                    if (!hash.equals(rs.getString("payload_hash"))) {
                        throw error(HttpStatus.CONFLICT, "REQUEST_CONFLICT", "같은 요청 번호로 다른 내용을 접수할 수 없어요.");
                    }
                    return new Receipt(rs.getString("id"), rs.getTimestamp("created_at").toLocalDateTime().atOffset(ZoneOffset.UTC));
                }, uid, kind, requestId).stream().findFirst().orElse(null);
    }

    private Receipt insert(long uid, String kind, String requestId, String hash, String category, String title,
                           String content, String reply, Long postId, String snapshot) {
        LocalDateTime now = LocalDateTime.now(ZoneOffset.UTC).truncatedTo(java.time.temporal.ChronoUnit.MICROS);
        GeneratedKeyHolder key = new GeneratedKeyHolder();
        jdbc.update(connection -> {
            var statement = connection.prepareStatement("""
                    INSERT INTO support_tickets
                    (requester_user_id,kind,request_id,payload_hash,category,title,content,reply_email,target_post_id,target_snapshot,created_at)
                    VALUES (?,?,?,?,?,?,?,?,?,?,?)
                    """, Statement.RETURN_GENERATED_KEYS);
            Object[] values = {uid, kind, requestId, hash, category, title, content, reply, postId, snapshot, now};
            for (int i = 0; i < values.length; i++) statement.setObject(i + 1, values[i]);
            return statement;
        }, key);
        long id = key.getKey().longValue();
        jdbc.update("INSERT INTO support_mail_outbox(ticket_id,next_attempt_at) VALUES (?,?)", id, now);
        return new Receipt(Long.toString(id), now.atOffset(ZoneOffset.UTC));
    }

    private String hash(Object payload) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(encode(payload).getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException impossible) {
            throw new IllegalStateException(impossible);
        }
    }

    private String encode(Object payload) {
        try { return json.writeValueAsString(payload); }
        catch (JsonProcessingException exception) { throw new IllegalStateException("Cannot encode support data", exception); }
    }

    private static ApiException error(HttpStatus status, String code, String message) {
        return new ApiException(status, "support-request", "Support request", message, code);
    }
}
