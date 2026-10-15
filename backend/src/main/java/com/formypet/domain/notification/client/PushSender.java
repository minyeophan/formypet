package com.formypet.domain.notification.client;

import java.util.List;

public interface PushSender {
    PushSendResult send(String type, Long sourceId, String title, String body, List<String> tokens);
}
