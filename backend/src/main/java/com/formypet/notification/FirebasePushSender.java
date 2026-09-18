package com.formypet.notification;

import com.google.firebase.FirebaseApp;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.MulticastMessage;
import com.google.firebase.messaging.MessagingErrorCode;
import com.google.firebase.messaging.AndroidConfig;
import com.google.firebase.messaging.AndroidNotification;
import com.google.firebase.messaging.FirebaseMessagingException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

import java.util.ArrayList;
import java.util.List;

@Component
@Slf4j
public class FirebasePushSender implements PushSender {
    private static final int MAX_BATCH = 500;

    @Override
    public PushSendResult send(String type, Long sourceId, String title, String body, List<String> tokens) {
        if (FirebaseApp.getApps().isEmpty()) {
            log.info("FCM push skipped: Firebase not configured");
            return PushSendResult.disabled();
        }
        if (tokens.isEmpty()) return PushSendResult.disabled();
        int success = 0;
        int failure = 0;
        List<String> invalid = new ArrayList<>();
        for (int start = 0; start < tokens.size(); start += MAX_BATCH) {
            List<String> batch = tokens.subList(start, Math.min(start + MAX_BATCH, tokens.size()));
            try {
                var message = MulticastMessage.builder().addAllTokens(batch)
                    .setAndroidConfig(AndroidConfig.builder().setPriority(AndroidConfig.Priority.HIGH)
                        .setNotification(AndroidNotification.builder().setChannelId("formypet_reminders").build()).build())
                    .setNotification(com.google.firebase.messaging.Notification.builder().setTitle(title).setBody(body).build())
                    .putData("type", type).putData("sourceId", String.valueOf(sourceId))
                    .putData("route", "CARE_SCHEDULE_REMINDER".equals(type)
                        ? "/routine/schedule/" + sourceId : "/routine/" + sourceId).build();
                var response = FirebaseMessaging.getInstance().sendEachForMulticast(message);
                success += response.getSuccessCount();
                failure += response.getFailureCount();
                for (int i = 0; i < response.getResponses().size(); i++) {
                    var sendResponse = response.getResponses().get(i);
                    if (!sendResponse.isSuccessful() && sendResponse.getException() != null) {
                        log.warn("FCM device request failed: code={}", sendResponse.getException().getMessagingErrorCode());
                    }
                    if (!sendResponse.isSuccessful() && sendResponse.getException() != null
                        && sendResponse.getException().getMessagingErrorCode() == MessagingErrorCode.UNREGISTERED) {
                        invalid.add(batch.get(i));
                    }
                }
            } catch (Exception error) {
                failure += batch.size();
                log.warn("FCM batch failed: size={}, code={}", batch.size(),
                    error instanceof FirebaseMessagingException fcm ? fcm.getMessagingErrorCode() : error.getClass().getSimpleName());
            }
        }
        log.info("FCM push result: success={}, failure={}, invalidTokens={}", success, failure, invalid.size());
        return new PushSendResult(success, failure, invalid);
    }
}
