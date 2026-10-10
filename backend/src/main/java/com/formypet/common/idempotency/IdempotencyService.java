package com.formypet.common.idempotency;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.formypet.auth.SessionGuard;
import com.formypet.common.exception.ApiException;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.web.multipart.MultipartFile;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.HexFormat;
import java.util.List;
import java.util.TreeMap;
import java.util.function.LongFunction;
import java.util.function.Supplier;
import java.util.function.ToLongFunction;

/** Serializes a logical save and its receipt in the same database transaction. */
@Service
@RequiredArgsConstructor
public class IdempotencyService {
    private final SessionGuard sessions;
    private final JdbcTemplate jdbc;
    private final ObjectMapper mapper;
    private final PlatformTransactionManager transactions;

    public <T> T execute(Long actorId, String operation, String target, String key,
                         Object payload, List<MultipartFile> files,
                         Supplier<T> create, ToLongFunction<T> resultId, LongFunction<T> replay) {
        if (key == null) return create.get();
        if (key.isBlank() || key.length() > 128 || !key.matches("[A-Za-z0-9._:-]+")) {
            throw new IllegalArgumentException("Idempotency-Key must contain 1 to 128 letters, digits, '.', '_', ':', or '-'.");
        }
        String fingerprint = fingerprint(payload, files);
        return new TransactionTemplate(transactions).execute(status ->
                executeLocked(actorId, operation, target, key, fingerprint, create, resultId, replay));
    }

    private <T> T executeLocked(Long actorId, String operation, String target, String key,
                                String fingerprint, Supplier<T> create,
                                ToLongFunction<T> resultId, LongFunction<T> replay) {
        // The account row predates receipts, closing the simultaneous first-request race.
        sessions.lockCurrent(actorId);
        var receipts = jdbc.query("""
                SELECT request_hash, result_id FROM idempotency_requests
                WHERE user_id=? AND operation=? AND target=? AND request_key=? FOR UPDATE
                """, (rs, n) -> new Receipt(rs.getString(1), rs.getLong(2)), actorId, operation, target, key);
        if (!receipts.isEmpty()) {
            Receipt receipt = receipts.getFirst();
            if (!receipt.hash().equals(fingerprint)) {
                throw new ApiException(HttpStatus.CONFLICT, "idempotency-conflict", "Idempotency conflict",
                        "This key was already used for different content.", "IDEMPOTENCY_CONFLICT");
            }
            return replay.apply(receipt.resultId());
        }
        T result = create.get();
        // Store identifiers only: deleted private content must not survive inside receipts.
        jdbc.update("""
                INSERT INTO idempotency_requests(user_id, operation, target, request_key, request_hash, result_id)
                VALUES (?, ?, ?, ?, ?, ?)
                """, actorId, operation, target, key, fingerprint, resultId.applyAsLong(result));
        return result;
    }

    public void requirePet(Long actorId, Long petId) {
        require(jdbc.queryForObject("SELECT COUNT(*) FROM pets WHERE id=? AND user_id=? AND is_deleted=false",
                Long.class, petId, actorId));
    }

    public void requireRecord(Long actorId, Long petId, Long recordId) {
        requirePet(actorId, petId);
        require(jdbc.queryForObject("SELECT COUNT(*) FROM activity_records WHERE id=? AND pet_id=?",
                Long.class, recordId, petId));
    }

    public void requirePost(Long actorId, Long postId) {
        require(jdbc.queryForObject("SELECT COUNT(*) FROM posts WHERE id=? AND user_id=?", Long.class, postId, actorId));
    }

    public com.formypet.media.dto.MediaResponse media(Long actorId, Long mediaId) {
        var rows = jdbc.query("""
                SELECT id, original_name, content_type, file_size, status FROM media_resources
                WHERE id=? AND user_id=? AND status='STORED'
                """, (rs, n) -> com.formypet.media.dto.MediaResponse.of(rs.getLong("id"),
                rs.getString("original_name"), rs.getString("content_type"), rs.getLong("file_size"), rs.getString("status")),
                mediaId, actorId);
        require((long) rows.size());
        return rows.getFirst();
    }

    private void require(Long count) {
        if (count == null || count == 0) throw new ApiException(HttpStatus.GONE, "idempotency-target-gone",
                "Save target gone", "The previously saved resource is no longer available.", "IDEMPOTENCY_TARGET_GONE");
    }

    private String fingerprint(Object payload, List<MultipartFile> files) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            update(digest, mapper.writeValueAsBytes(canonical(mapper.valueToTree(payload))));
            for (MultipartFile file : files) {
                update(digest, String.valueOf(file.getOriginalFilename()).getBytes(StandardCharsets.UTF_8));
                update(digest, String.valueOf(file.getContentType()).getBytes(StandardCharsets.UTF_8));
                update(digest, file.getBytes());
            }
            return HexFormat.of().formatHex(digest.digest());
        } catch (java.io.IOException | java.security.NoSuchAlgorithmException e) {
            throw new IllegalStateException("Cannot fingerprint save request.", e);
        }
    }

    private Object canonical(JsonNode node) {
        if (node.isObject()) {
            var sorted = new TreeMap<String, Object>();
            node.fields().forEachRemaining(entry -> sorted.put(entry.getKey(), canonical(entry.getValue())));
            return sorted;
        }
        if (node.isArray()) {
            var values = new java.util.ArrayList<Object>();
            node.forEach(value -> values.add(canonical(value)));
            return values;
        }
        return node;
    }

    private void update(MessageDigest digest, byte[] bytes) {
        digest.update(java.nio.ByteBuffer.allocate(Long.BYTES).putLong(bytes.length).array());
        digest.update(bytes);
    }

    private record Receipt(String hash, long resultId) {}
}
