package com.formypet.user;

import com.formypet.common.exception.ApiException;
import com.formypet.common.ratelimit.RequestRateLimiter;
import com.formypet.common.ratelimit.RequestRateLimitProperties;
import com.formypet.support.SupportMailProperties;
import com.formypet.support.SupportMailTransport;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.assertj.core.api.Assertions.assertThat;

@ExtendWith(MockitoExtension.class)
class PublicAccountDeletionRequestServiceTest {
    @Mock SupportMailProperties settings;
    @Mock SupportMailTransport mail;
    @Mock RequestRateLimiter requestRateLimiter;
    @Mock RequestRateLimitProperties requestLimits;
    @InjectMocks PublicAccountDeletionRequestService service;

    @Test
    void sendsManualDeletionRequestToConfiguredSupportAndReturnsReceipt() throws Exception {
        when(settings.isEnabled()).thenReturn(true);
        when(requestLimits.getDeletionEmailCapacity()).thenReturn(3);
        when(requestLimits.getDeletionEmailWindowSeconds()).thenReturn(3600);
        when(requestLimits.getDeletionClientCapacity()).thenReturn(10);
        when(requestLimits.getDeletionClientWindowSeconds()).thenReturn(3600);
        when(requestLimits.getDeletionGlobalCapacity()).thenReturn(100);
        when(requestLimits.getDeletionGlobalWindowSeconds()).thenReturn(3600);
        var request = new PublicAccountDeletionRequest("contact@example.test", "kakao nickname", "req-123");

        var receipt = service.submit(request, "127.0.0.1");

        assertEquals("req-123", receipt.requestId());
        var captured = org.mockito.ArgumentCaptor.forClass(List.class);
        verify(requestRateLimiter).consume(anyList(), captured.capture());
        @SuppressWarnings("unchecked")
        var windows = (List<RequestRateLimiter.SlidingWindow>) captured.getValue();
        assertThat(windows).extracting(RequestRateLimiter.SlidingWindow::scope)
                .containsExactly("deletion-email-hour", "deletion-client", "deletion-global");
        assertThat(windows).extracting(RequestRateLimiter.SlidingWindow::maxRequests).containsExactly(3, 10, 100);
        assertThat(windows).extracting(RequestRateLimiter.SlidingWindow::windowSeconds)
                .containsExactly(3600, 3600, 3600);
        verify(mail).send(contains("req-123"), contains("kakao nickname"), eq("contact@example.test"));
    }

    @Test
    void disabledSupportMailDoesNotAcceptOrPersistPublicRequests() {
        when(settings.isEnabled()).thenReturn(false);
        var request = new PublicAccountDeletionRequest("contact@example.test", "member", "req-456");

        ApiException failure = assertThrows(ApiException.class, () -> service.submit(request, "127.0.0.1"));

        assertEquals(HttpStatus.SERVICE_UNAVAILABLE, failure.status());
        verifyNoInteractions(mail);
        verifyNoInteractions(requestRateLimiter);
    }

    @Test
    void sharedLimiterBlocksRepeatedRequestsBeforeMailIsSent() throws Exception {
        when(settings.isEnabled()).thenReturn(true);
        when(requestRateLimiter.consume(anyList(), anyList())).thenReturn(0).thenThrow(new ApiException(
                HttpStatus.TOO_MANY_REQUESTS, "rate-limited", "Too many requests", "wait", "RATE_LIMITED", 30));
        service.submit(new PublicAccountDeletionRequest("same@example.test", "one", "req-one"), "127.0.0.1");

        ApiException failure = assertThrows(ApiException.class, () -> service.submit(
                new PublicAccountDeletionRequest("SAME@example.test", "two", "req-two"), "127.0.0.1"));

        assertEquals(HttpStatus.TOO_MANY_REQUESTS, failure.status());
        verify(mail, times(1)).send(anyString(), anyString(), anyString());
        verify(requestRateLimiter, times(2)).consume(anyList(), anyList());
    }
}
