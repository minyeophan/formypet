package com.formypet.domain.user.entity;

/** Existing provider and webhook retry policy, independent of persistence and scheduling. */
public final class AccountCleanupRetry {
    private AccountCleanupRetry() {}

    public static long delaySeconds(int previousAttempts) {
        return Math.min(86400L, 30L << Math.min(previousAttempts, 11));
    }

    public static int nextWebhookAttempt(int previousAttempts) {
        return Math.min(previousAttempts + 1, 30);
    }
}
