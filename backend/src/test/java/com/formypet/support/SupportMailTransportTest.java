package com.formypet.support;

import jakarta.mail.Session;
import jakarta.mail.internet.MimeMessage;
import org.junit.jupiter.api.Test;
import org.springframework.mail.javamail.JavaMailSenderImpl;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.Properties;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class SupportMailTransportTest {
    @Test void createsPlainTextKoreanMailWithConfiguredRecipientAndReplyTo() throws Exception {
        var settings = settings();
        var transport = new SupportMailTransport(settings);
        transport.configure();
        var sender = mock(JavaMailSenderImpl.class);
        var message = new MimeMessage(Session.getInstance(new Properties()));
        when(sender.createMimeMessage()).thenReturn(message);
        ReflectionTestUtils.setField(transport, "sender", sender);
        transport.send("[포마펫][문의 #1] 문의 제목", "문의 본문 <b>그대로</b>", "reply@example.test");
        message.saveChanges();
        assertEquals("admin@example.test", message.getAllRecipients()[0].toString());
        assertEquals("reply@example.test", message.getReplyTo()[0].toString());
        assertEquals("[포마펫][문의 #1] 문의 제목", message.getSubject());
        assertEquals("문의 본문 <b>그대로</b>", message.getContent());
        assertTrue(message.isMimeType("text/plain"));
        verify(sender).send(message);
    }

    @Test void rejectsHeaderInjectionBeforeSending() throws Exception {
        var transport = new SupportMailTransport(settings());
        transport.configure();
        var sender = mock(JavaMailSenderImpl.class);
        when(sender.createMimeMessage()).thenReturn(new MimeMessage(Session.getInstance(new Properties())));
        ReflectionTestUtils.setField(transport, "sender", sender);
        assertThrows(IllegalArgumentException.class, () -> transport.send("제목\r\nBcc: other@example.test", "body", null));
        assertThrows(IllegalArgumentException.class, () -> transport.send("제목", "body", "reply@example.test\nBcc: other@example.test"));
        verify(sender, never()).send(any(MimeMessage.class));
    }

    @Test void disabledTransportNeverConnectsAndEnabledNeedsCredentials() {
        var disabled = new SupportMailTransport(new SupportMailProperties());
        disabled.configure();
        assertThrows(IllegalStateException.class, () -> disabled.send("제목", "body", null));
        var settings = settings();
        settings.setPassword("");
        assertThrows(IllegalStateException.class, () -> new SupportMailTransport(settings).configure());
    }

    @Test void transportRequiresTlsIdentityCheckAndBoundedTimeouts() {
        var transport = new SupportMailTransport(settings());
        transport.configure();
        var sender = (JavaMailSenderImpl) ReflectionTestUtils.getField(transport, "sender");
        assertEquals("true", sender.getJavaMailProperties().getProperty("mail.smtp.starttls.required"));
        assertEquals("true", sender.getJavaMailProperties().getProperty("mail.smtp.ssl.checkserveridentity"));
        for (String property : new String[]{"connectiontimeout", "timeout", "writetimeout"}) {
            assertEquals("10000", sender.getJavaMailProperties().getProperty("mail.smtp." + property));
        }
    }

    private SupportMailProperties settings() {
        var settings = new SupportMailProperties();
        settings.setEnabled(true);
        settings.setUsername("sender@example.test");
        settings.setRecipient("admin@example.test");
        settings.setPassword("test-placeholder-not-a-secret");
        return settings;
    }
}
