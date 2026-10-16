package com.formypet.global.ratelimit;

import com.formypet.global.exception.ApiException;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.dao.DataAccessException;
import org.springframework.http.HttpStatus;
import com.formypet.global.ratelimit.repository.RequestRateLimitRepository;
import org.springframework.stereotype.Component;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.support.TransactionTemplate;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.Comparator;
import java.util.HexFormat;
import java.util.List;

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

    private final RequestRateLimitRepository limits;
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
            limits.initializeAndLock(lock.scope(), lock.key(), capacity, now);
        }
        var rows = new java.util.ArrayList<Row>();
        int retryAfter = 1;
        for (Bucket bucket : buckets) {
            String key = digest(bucket.scope() + "\0" + bucket.identifier());
            var row = limits.lockState(bucket.scope(), key);
            double stored = row.available();
            Instant updated = row.updatedAt();
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
            int current = limits.countEventsAfter(window.scope(), key, start);
            windowCounts.add(current);
            if (current + window.cost() > window.maxRequests()) {
                Long oldest = limits.oldestEventOffset(window.scope(), key, start, now,
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
            limits.updateTokens(row.bucket().scope(), row.key(), row.available() - row.bucket().cost(), now);
        }
        for (int i = 0; i < windows.size(); i++) {
            SlidingWindow window = windows.get(i);
            String key = digest(window.scope() + "\0" + window.identifier());
            for (int event = 0; event < window.cost(); event++) {
                limits.addEvent(window.scope(), key, now);
            }
            limits.touch(window.scope(), key, now);
        }
        return 0;
    }

    static double refilledTokens(double stored, double elapsedSeconds, int capacity,
                                 int refillTokens, int refillPeriodSeconds) {
        return Math.min(capacity, stored + elapsedSeconds * refillTokens / refillPeriodSeconds);
    }

    @Scheduled(fixedDelay = 3_600_000L)
    public void cleanup() {
        limits.deleteEventsBefore(Instant.now().minus(Duration.ofHours(2)));
        limits.deleteBucketsBefore(Instant.now().minus(Duration.ofHours(2)));
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

}
