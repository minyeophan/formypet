package com.formypet.domain.support.service.impl;

import com.formypet.domain.support.service.SupportService;
import com.formypet.domain.support.dto.request.InquiryRequest;
import com.formypet.domain.support.dto.request.ReportRequest;
import com.formypet.domain.support.dto.response.SupportReceipt;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.formypet.common.exception.ApiException;
import com.formypet.domain.support.entity.SupportMailOutbox;
import com.formypet.domain.support.entity.SupportTicket;
import com.formypet.domain.support.repository.SupportMailOutboxRepository;
import com.formypet.domain.support.repository.SupportTicketRepository;
import com.formypet.domain.support.repository.query.SupportAccessRepository;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Instant;
import java.util.HexFormat;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class SupportServiceImpl implements SupportService {
    private final SupportTicketRepository tickets;
    private final SupportMailOutboxRepository outbox;
    private final SupportAccessRepository access;
    private final ObjectMapper json;

    @Transactional
    public SupportReceipt inquiry(Long actorId, InquiryRequest request) {
        long uid = lockUser(actorId);
        String title = request.title().trim();
        String body = request.body().trim();
        String reply = request.replyEmail().trim();
        String hash = hash(List.of(request.type(), title, body, reply));
        SupportReceipt existing = existing(uid, "INQUIRY", request.requestId(), hash);
        if (existing != null) return existing;
        return insert(uid, "INQUIRY", request.requestId(), hash, request.type(), title, body, reply, null, null, null);
    }

    @Transactional
    public SupportReceipt report(Long actorId, long postId, ReportRequest request) {
        long uid = lockUser(actorId);
        String detail = request.detail() == null ? "" : request.detail().trim();
        if (request.reason().equals("OTHER") && detail.isEmpty()) {
            throw error(HttpStatus.BAD_REQUEST, "REPORT_DETAIL_REQUIRED", "기타 사유의 상세 내용을 입력해 주세요.");
        }
        String hash = hash(List.of(postId, request.reason(), detail));
        // A successfully accepted request stays retryable after its target is deleted.
        SupportReceipt existing = existing(uid, "POST_REPORT", request.requestId(), hash);
        if (existing != null) return existing;
        if (tickets.existsByRequesterUserIdAndTargetPostId(uid, postId)) {
            throw error(HttpStatus.CONFLICT, "POST_ALREADY_REPORTED", "이미 신고한 게시글이에요.");
        }
        var post = access.post(postId).orElseThrow(() ->
                error(HttpStatus.NOT_FOUND, "POST_NOT_FOUND", "게시글을 찾을 수 없어요."));
        if (post.userId() == uid) {
            throw error(HttpStatus.FORBIDDEN, "SELF_REPORT_FORBIDDEN", "본인 게시글은 신고할 수 없어요.");
        }
        return insert(uid, "POST_REPORT", request.requestId(), hash, request.reason(), "게시글 신고", detail,
                null, postId, encode(post), post.userId());
    }

    private long lockUser(Long actorId) {
        return access.lockUser(actorId).orElseThrow(() ->
                error(HttpStatus.UNAUTHORIZED, "UNAUTHORIZED", "로그인이 필요해요."));
    }

    private SupportReceipt existing(long uid, String kind, String requestId, String hash) {
        return tickets.findByRequesterUserIdAndKindAndRequestId(uid, kind, requestId).map(ticket -> {
            if (!ticket.matchesPayload(hash)) {
                throw error(HttpStatus.CONFLICT, "REQUEST_CONFLICT", "같은 요청 번호로 다른 내용을 접수할 수 없어요.");
            }
            return receipt(ticket);
        }).orElse(null);
    }

    private SupportReceipt insert(long uid, String kind, String requestId, String hash, String category, String title,
                           String content, String reply, Long postId, String snapshot, Long authorId) {
        var ticket = tickets.saveAndFlush(SupportTicket.received(uid, kind, requestId, hash, category,
                title, content, reply, postId, snapshot, authorId, Instant.now()));
        outbox.saveAndFlush(SupportMailOutbox.pending(ticket.getId(), ticket.receivedAt()));
        return receipt(ticket);
    }

    private static SupportReceipt receipt(SupportTicket ticket) {
        return new SupportReceipt(ticket.getId().toString(), ticket.receivedAt());
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
