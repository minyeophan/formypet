package com.formypet.global.idempotency;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.formypet.domain.auth.security.SessionGuard;
import com.formypet.global.exception.ApiException;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import com.formypet.global.idempotency.repository.IdempotencyRepository;
import com.formypet.global.idempotency.repository.ReplayTargetRepository;
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
import java.util.function.BiFunction;
import java.util.function.Function;
import java.util.function.Supplier;
import java.util.function.ToLongFunction;

/** Serializes a logical save and its receipt in the same database transaction. */
@Service
@RequiredArgsConstructor
public class IdempotencyService {
    private final SessionGuard sessions;
    private final IdempotencyRepository receipts;
    private final ReplayTargetRepository targets;
    private final ObjectMapper mapper;
    private final PlatformTransactionManager transactions;

    public <T> T execute(Long actorId, String operation, String target, String key,
                         Object payload, List<MultipartFile> files,
                         Supplier<T> create, ToLongFunction<T> resultId, LongFunction<T> replay) {
        return executeInternal(actorId,operation,target,key,payload,files,create,resultId,value->null,
                (id,version)->replay.apply(id));
    }

    public <T> T executeVersioned(Long actorId, String operation, String target, String key,
                                  Object payload, List<MultipartFile> files, Supplier<T> create,
                                  ToLongFunction<T> resultId, Function<T,Long> resultVersion,
                                  BiFunction<Long,Long,T> replay) {
        return executeInternal(actorId,operation,target,key,payload,files,create,resultId,resultVersion,replay);
    }

    private <T> T executeInternal(Long actorId, String operation, String target, String key,
                         Object payload, List<MultipartFile> files,
                         Supplier<T> create, ToLongFunction<T> resultId, Function<T,Long> resultVersion,
                         BiFunction<Long,Long,T> replay) {
        if (key == null) return create.get();
        if (key.isBlank() || key.length() > 128 || !key.matches("[A-Za-z0-9._:-]+")) {
            throw new IllegalArgumentException("Idempotency-Key must contain 1 to 128 letters, digits, '.', '_', ':', or '-'.");
        }
        String fingerprint = fingerprint(payload, files);
        return new TransactionTemplate(transactions).execute(status ->
                executeLocked(actorId, operation, target, key, fingerprint, create, resultId, resultVersion, replay));
    }

    private <T> T executeLocked(Long actorId, String operation, String target, String key,
                                String fingerprint, Supplier<T> create,
                                ToLongFunction<T> resultId, Function<T,Long> resultVersion,
                                BiFunction<Long,Long,T> replay) {
        // The account row predates receipts, closing the simultaneous first-request race.
        sessions.lockCurrent(actorId);
        var existing = receipts.findCurrent(actorId, operation, target, key);
        if (existing.isPresent()) {
            var receipt = existing.orElseThrow();
            if (!receipt.hash().equals(fingerprint)) {
                throw new ApiException(HttpStatus.CONFLICT, "idempotency-conflict", "Idempotency conflict",
                        "This key was already used for different content.", "IDEMPOTENCY_CONFLICT");
            }
            return replay.apply(receipt.resultId(),receipt.resultVersion());
        }
        T result = create.get();
        // Store identifiers only: deleted private content must not survive inside receipts.
        receipts.insert(actorId, operation, target, key, fingerprint, resultId.applyAsLong(result), resultVersion.apply(result));
        return result;
    }

    public void requirePet(Long actorId, Long petId) {
        require(targets.petExists(actorId, petId));
    }

    public void requireRecord(Long actorId, Long petId, Long recordId) {
        requirePet(actorId, petId);
        require(targets.recordExists(petId, recordId));
    }

    public void requirePost(Long actorId, Long postId) {
        require(targets.postExists(actorId, postId));
    }

    public com.formypet.domain.media.dto.response.MediaResponse media(Long actorId, Long mediaId) {
        var found = targets.findStoredMedia(actorId, mediaId);
        require(found.isPresent());
        var row = found.orElseThrow();
        return com.formypet.domain.media.dto.response.MediaResponse.of(row.id(), row.originalName(),
                row.contentType(), row.fileSize(), row.status());
    }

    private void require(boolean exists) {
        if (!exists) throw new ApiException(HttpStatus.GONE, "idempotency-target-gone",
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

}
