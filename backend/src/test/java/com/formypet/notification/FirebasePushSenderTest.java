package com.formypet.notification;

import com.google.firebase.FirebaseApp;
import com.google.firebase.messaging.*;
import org.junit.jupiter.api.Test;
import java.util.*;
import java.util.stream.IntStream;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class FirebasePushSenderTest {
    @Test
    void splits1001DevicesInto5005001AndPreservesOrder() throws Exception {
        var messaging = mock(FirebaseMessaging.class);
        var received = new ArrayList<List<String>>();
        when(messaging.sendEachForMulticast(any())).thenAnswer(call -> {
            var message = (MulticastMessage) call.getArgument(0);
            var field = MulticastMessage.class.getDeclaredField("tokens");
            field.setAccessible(true);
            @SuppressWarnings("unchecked") var tokens = (List<String>) field.get(message);
            received.add(List.copyOf(tokens));
            return response(tokens.size(), 0, Collections.nCopies(tokens.size(), success()));
        });
        try (var apps = mockStatic(FirebaseApp.class); var instances = mockStatic(FirebaseMessaging.class)) {
            apps.when(FirebaseApp::getApps).thenReturn(List.of(mock(FirebaseApp.class)));
            instances.when(FirebaseMessaging::getInstance).thenReturn(messaging);
            var tokens = IntStream.range(0, 1001).mapToObj(i -> "device-" + i).toList();
            var result = new FirebasePushSender().send("ROUTINE_REMINDER", 7L, "title", "body", tokens);
            assertEquals(List.of(500, 500, 1), received.stream().map(List::size).toList());
            assertEquals(tokens, received.stream().flatMap(List::stream).toList());
            assertEquals(1001, result.successCount());
            assertEquals(0, result.failureCount());
        }
    }

    @Test
    void onlyUnregisteredIsInvalidAndBatchFailureDoesNotStopFollowingBatch() throws Exception {
        var messaging = mock(FirebaseMessaging.class);
        var responses = new ArrayList<SendResponse>(Collections.nCopies(500, success()));
        responses.set(0, failure(MessagingErrorCode.UNREGISTERED));
        responses.set(1, failure(MessagingErrorCode.UNAVAILABLE));
        responses.set(2, failure(MessagingErrorCode.INVALID_ARGUMENT));
        var partial = response(497, 3, responses);
        var last = response(1, 0, List.of(success()));
        when(messaging.sendEachForMulticast(any()))
            .thenReturn(partial)
            .thenThrow(new IllegalStateException("simulated transport failure"))
            .thenReturn(last);
        try (var apps = mockStatic(FirebaseApp.class); var instances = mockStatic(FirebaseMessaging.class)) {
            apps.when(FirebaseApp::getApps).thenReturn(List.of(mock(FirebaseApp.class)));
            instances.when(FirebaseMessaging::getInstance).thenReturn(messaging);
            var result = new FirebasePushSender().send("ROUTINE_REMINDER", 7L, "title", "body",
                IntStream.range(0, 1001).mapToObj(i -> "device-" + i).toList());
            assertEquals(498, result.successCount());
            assertEquals(503, result.failureCount());
            assertEquals(List.of("device-0"), result.invalidTokens());
            verify(messaging, times(3)).sendEachForMulticast(any());
        }
    }

    private static BatchResponse response(int ok, int failed, List<SendResponse> responses) {
        var response = mock(BatchResponse.class);
        when(response.getSuccessCount()).thenReturn(ok);
        when(response.getFailureCount()).thenReturn(failed);
        when(response.getResponses()).thenReturn(responses);
        return response;
    }
    private static SendResponse success() {
        var response = mock(SendResponse.class);
        when(response.isSuccessful()).thenReturn(true);
        return response;
    }
    private static SendResponse failure(MessagingErrorCode code) {
        var exception = mock(FirebaseMessagingException.class);
        when(exception.getMessagingErrorCode()).thenReturn(code);
        var response = mock(SendResponse.class);
        when(response.getException()).thenReturn(exception);
        return response;
    }
}
