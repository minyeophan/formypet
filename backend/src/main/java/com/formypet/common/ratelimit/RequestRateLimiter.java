package com.formypet.common.ratelimit;

import com.formypet.common.exception.ApiException;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.dao.DataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.support.TransactionTemplate;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.sql.Timestamp;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.time.Duration;
import java.time.Instant;
import java.util.Comparator;
import java.util.HexFormat;
import java.util.List;

/** Durable request admission control. Limits are checked and consumed in one ordered transaction. */
@Component
@RequiredArgsConstructor
public class RequestRateLimiter {
    public record Bucket(String scope, String identifier, int capacity, int refillTokens,
                         int refillPeriodSeconds, int cost) {
        public Bucket(String scope, String identifier, int capacity, int refillSeconds, int cost) {
            this(scope, identifier, capacity, 1, refillSeconds, cost);
        }
        public Bucket(String scope, String identifier, int capacity, int refillSeconds) {
            this(scope, identifier, capacity, 1, refillSeconds, 1);
        }
    }
    public record SlidingWindow(String scope, String identifier, int maxRequests, int windowSeconds, int cost) {}
    private record LockKey(String scope, String identifier, String key) {}
    private record Row(Bucket bucket, String key, double available, Instant updatedAt) {}

    private final JdbcTemplate jdbc;
    private final PlatformTransactionManager transactionManager;
    @Value("${app.jwt.secret}") private String hmacKey;

    public int consume(List<Bucket> requested) {
        return consume(requested, List.of());
    }

    public int consume(List<Bucket> requested, List<SlidingWindow> windows) {
        return consumeAt(requested, windows, Instant.now());
    }

    int consumeAt(List<Bucket> requested, List<SlidingWindow> windows, Instant now) {
        var ordered = requested.stream()
                .sorted(Comparator.comparing(Bucket::scope).thenComparing(Bucket::identifier))
                .toList();
        var orderedWindows = windows.stream()
                .sorted(Comparator.comparing(SlidingWindow::scope).thenComparing(SlidingWindow::identifier))
                .toList();
        TransactionTemplate tx = new TransactionTemplate(transactionManager);
        tx.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRES_NEW);
        try {
            return tx.execute(status -> consumeLocked(ordered, orderedWindows, now));
        } catch (DataAccessException failure) {
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "request-limit-unavailable",
                    "Request temporarily unavailable", "요청을 처리할 수 없습니다. 잠시 후 다시 시도해 주세요.",
                    "REQUEST_LIMIT_UNAVAILABLE");
        }
    }

    private int consumeLocked(List<Bucket> buckets, List<SlidingWindow> windows, Instant now) {
        var lockKeys = new java.util.ArrayList<LockKey>();
        buckets.forEach(bucket -> lockKeys.add(new LockKey(bucket.scope(), bucket.identifier(),
                digest(bucket.scope() + "\0" + bucket.identifier()))));
        windows.forEach(window -> lockKeys.add(new LockKey(window.scope(), window.identifier(),
                digest(window.scope() + "\0" + window.identifier()))));
        lockKeys.sort(Comparator.comparing(LockKey::scope).thenComparing(LockKey::identifier));
        for (LockKey lock : lockKeys) {
            int capacity = buckets.stream().filter(bucket -> bucket.scope().equals(lock.scope())
                    && digest(bucket.scope() + "\0" + bucket.identifier()).equals(lock.key()))
                    .mapToInt(Bucket::capacity).findFirst().orElse(0);
            jdbc.update("""
                    INSERT IGNORE INTO request_rate_limits(scope,bucket_key,available_tokens,updated_at)
                    VALUES(?,?,?,?)
                    """, lock.scope(), lock.key(), capacity, Timestamp.from(now));
            jdbc.queryForObject("""
                    SELECT available_tokens FROM request_rate_limits
                    WHERE scope=? AND bucket_key=? FOR UPDATE
                    """, Double.class, lock.scope(), lock.key());
        }
        var rows = new java.util.ArrayList<Row>();
        int retryAfter = 1;
        for (Bucket bucket : buckets) {
            String key = digest(bucket.scope() + "\0" + bucket.identifier());
            var row = jdbc.queryForMap("""
                    SELECT available_tokens,updated_at FROM request_rate_limits
                    WHERE scope=? AND bucket_key=? FOR UPDATE
                    """, bucket.scope(), key);
            double stored = ((Number) row.get("available_tokens")).doubleValue();
            Instant updated = toInstant(row.get("updated_at"));
            double elapsed = Math.max(0, Duration.between(updated, now).toNanos() / 1_000_000_000d);
            double available = refilledTokens(stored, elapsed, bucket.capacity(),
                    bucket.refillTokens(), bucket.refillPeriodSeconds());
            if (available < bucket.cost()) {
                retryAfter = Math.max(retryAfter,
                        (int) Math.ceil((bucket.cost() - available) * bucket.refillPeriodSeconds()
                                / bucket.refillTokens()));
            }
            rows.add(new Row(bucket, key, available, updated));
        }
        var windowCounts = new java.util.ArrayList<Integer>();
        for (SlidingWindow window : windows) {
            String key = digest(window.scope() + "\0" + window.identifier());
            Instant start = now.minusSeconds(window.windowSeconds());
            Integer count = jdbc.queryForObject("""
                    SELECT COUNT(*) FROM request_rate_limit_events
                    WHERE scope=? AND bucket_key=? AND occurred_at>?
                    """, Integer.class, window.scope(), key, Timestamp.from(start));
            int current = count == null ? 0 : count;
            windowCounts.add(current);
            if (current + window.cost() > window.maxRequests()) {
                Long oldest = jdbc.queryForObject("""
                        SELECT TIMESTAMPDIFF(SECOND, ?, MIN(occurred_at)) FROM (
                          SELECT occurred_at FROM request_rate_limit_events
                          WHERE scope=? AND bucket_key=? AND occurred_at>? ORDER BY occurred_at LIMIT ?
                        ) active_events
                        """, Long.class, Timestamp.from(now), window.scope(), key, Timestamp.from(start),
                        current + window.cost() - window.maxRequests());
                if (oldest != null) retryAfter = Math.max(retryAfter, (int) Math.max(1, window.windowSeconds() + oldest));
            }
        }
        if (rows.stream().anyMatch(row -> row.available() < row.bucket().cost())) {
            throw new ApiException(HttpStatus.TOO_MANY_REQUESTS, "rate-limited",
                    "Too many requests", "요청이 많아요. 잠시 후 다시 시도해 주세요.",
                    "RATE_LIMITED", retryAfter);
        }
        boolean windowDenied = false;
        for (int i = 0; i < windows.size(); i++) {
            windowDenied |= windowCounts.get(i) + windows.get(i).cost() > windows.get(i).maxRequests();
        }
        if (windowDenied) {
            throw new ApiException(HttpStatus.TOO_MANY_REQUESTS, "rate-limited",
                    "Too many requests", "요청이 많아요. 잠시 후 다시 시도해 주세요.",
                    "RATE_LIMITED", retryAfter);
        }
        for (Row row : rows) {
            jdbc.update("""
                    UPDATE request_rate_limits SET available_tokens=?,updated_at=?
                    WHERE scope=? AND bucket_key=?
                    """, row.available() - row.bucket().cost(), Timestamp.from(now), row.bucket().scope(), row.key());
        }
        for (int i = 0; i < windows.size(); i++) {
            SlidingWindow window = windows.get(i);
            String key = digest(window.scope() + "\0" + window.identifier());
            for (int event = 0; event < window.cost(); event++) {
                jdbc.update("INSERT INTO request_rate_limit_events(scope,bucket_key,occurred_at) VALUES(?,?,?)",
                        window.scope(), key, Timestamp.from(now));
            }
            jdbc.update("UPDATE request_rate_limits SET updated_at=? WHERE scope=? AND bucket_key=?",
                    Timestamp.from(now), window.scope(), key);
        }
        return 0;
    }

    static double refilledTokens(double stored, double elapsedSeconds, int capacity,
                                 int refillTokens, int refillPeriodSeconds) {
        return Math.min(capacity, stored + elapsedSeconds * refillTokens / refillPeriodSeconds);
    }

    @Scheduled(fixedDelay = 3_600_000L)
    public void cleanup() {
        jdbc.update("DELETE FROM request_rate_limit_events WHERE occurred_at < ?",
                Timestamp.from(Instant.now().minus(Duration.ofHours(2))));
        jdbc.update("DELETE FROM request_rate_limits WHERE updated_at < ?",
                Timestamp.from(Instant.now().minus(Duration.ofHours(2))));
    }

    private String digest(String value) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(hmacKey.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
            return HexFormat.of().formatHex(mac.doFinal(value.getBytes(StandardCharsets.UTF_8)));
        } catch (java.security.GeneralSecurityException failure) {
            throw new IllegalStateException("Request limiter hashing unavailable");
        }
    }

    private Instant toInstant(Object value) {
        if (value instanceof Timestamp timestamp) return timestamp.toInstant();
        if (value instanceof LocalDateTime localDateTime) return localDateTime.toInstant(ZoneOffset.UTC);
        throw new IllegalStateException("Unexpected request limit timestamp type");
    }
}
