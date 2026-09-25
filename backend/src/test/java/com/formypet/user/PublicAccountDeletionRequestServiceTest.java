package com.formypet.user;

import com.formypet.common.exception.ApiException;
import com.formypet.support.SupportMailProperties;
import com.formypet.support.SupportMailTransport;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class PublicAccountDeletionRequestServiceTest {
    @Mock SupportMailProperties settings;
    @Mock SupportMailTransport mail;
    @InjectMocks PublicAccountDeletionRequestService service;

    @Test
    void sendsManualDeletionRequestToConfiguredSupportAndReturnsReceipt() throws Exception {
        when(settings.isEnabled()).thenReturn(true);
        var request = new PublicAccountDeletionRequest("contact@example.test", "kakao nickname", "req-123");

        var receipt = service.submit(request);

        assertEquals("req-123", receipt.requestId());
        verify(mail).send(contains("req-123"), contains("kakao nickname"), eq("contact@example.test"));
    }

    @Test
    void disabledSupportMailDoesNotAcceptOrPersistPublicRequests() {
        when(settings.isEnabled()).thenReturn(false);
        var request = new PublicAccountDeletionRequest("contact@example.test", "member", "req-456");

        ApiException failure = assertThrows(ApiException.class, () -> service.submit(request));

        assertEquals(HttpStatus.SERVICE_UNAVAILABLE, failure.status());
        verifyNoInteractions(mail);
    }

    @Test
    void limitsRepeatedRequestsForSameContactEmail() throws Exception {
        when(settings.isEnabled()).thenReturn(true);
        service.submit(new PublicAccountDeletionRequest("same@example.test", "one", "req-one"));

        ApiException failure = assertThrows(ApiException.class, () -> service.submit(
                new PublicAccountDeletionRequest("SAME@example.test", "two", "req-two")));

        assertEquals(HttpStatus.TOO_MANY_REQUESTS, failure.status());
        verify(mail, times(1)).send(anyString(), anyString(), anyString());
    }
}
