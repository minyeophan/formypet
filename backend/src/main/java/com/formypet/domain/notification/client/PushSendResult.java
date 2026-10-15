package com.formypet.domain.notification.client;

import java.util.List;

public record PushSendResult(int successCount, int failureCount, List<String> invalidTokens) {
    public static PushSendResult disabled() { return new PushSendResult(0, 0, List.of()); }
}
