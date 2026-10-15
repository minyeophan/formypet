package com.formypet.domain.support.entity;

import java.time.Instant;

public final class MailRetryPolicy {
    public static final int MAX_ATTEMPTS = 5;
    public static final int LEASE_SECONDS = 300;
    private static final int[] RETRY_MINUTES = {1, 5, 30, 120};
    private MailRetryPolicy() {}

    public static boolean exhausted(int attempt) { return attempt >= MAX_ATTEMPTS; }
    public static Instant nextAttempt(Instant now, int attempt) {
        return now.plusSeconds(exhausted(attempt) ? 0 : 60L * RETRY_MINUTES[attempt - 1]);
    }
}
