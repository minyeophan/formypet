package com.formypet.support;

import jakarta.annotation.PostConstruct;
import jakarta.mail.internet.InternetAddress;
import lombok.RequiredArgsConstructor;
import org.springframework.mail.javamail.JavaMailSenderImpl;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
public class SupportMailTransport {
    private final SupportMailProperties settings;
    private JavaMailSenderImpl sender;

    @PostConstruct
    void configure() {
        if (!settings.isEnabled()) return;
        try {
            validateAddress(settings.getUsername());
            validateAddress(settings.getRecipient());
            if (settings.getPassword().isBlank()) throw new IllegalArgumentException();
            if (settings.getSenderName().contains("\r") || settings.getSenderName().contains("\n")) throw new IllegalArgumentException();
        } catch (Exception invalid) {
            throw new IllegalStateException("Support SMTP requires valid sender, recipient and app password");
        }
        sender = new JavaMailSenderImpl();
        sender.setHost(settings.getHost());
        sender.setPort(settings.getPort());
        sender.setUsername(settings.getUsername());
        sender.setPassword(settings.getPassword());
        sender.setDefaultEncoding("UTF-8");
        var properties = sender.getJavaMailProperties();
        properties.setProperty("mail.smtp.auth", "true");
        properties.setProperty("mail.smtp.starttls.enable", "true");
        properties.setProperty("mail.smtp.starttls.required", "true");
        properties.setProperty("mail.smtp.ssl.checkserveridentity", "true");
        properties.setProperty("mail.smtp.connectiontimeout", "10000");
        properties.setProperty("mail.smtp.timeout", "10000");
        properties.setProperty("mail.smtp.writetimeout", "10000");
    }

    public void send(String subject, String body, String replyTo) throws Exception {
        if (sender == null) throw new IllegalStateException("Support SMTP is disabled");
        if (subject.contains("\r") || subject.contains("\n")) throw new IllegalArgumentException("Invalid subject");
        var message = sender.createMimeMessage();
        var helper = new MimeMessageHelper(message, false, "UTF-8");
        helper.setFrom(settings.getUsername(), settings.getSenderName());
        helper.setTo(settings.getRecipient());
        if (replyTo != null) {
            validateAddress(replyTo);
            helper.setReplyTo(replyTo);
        }
        helper.setSubject(subject);
        helper.setText(body, false);
        sender.send(message);
    }

    private static void validateAddress(String value) throws Exception {
        if (value == null || value.contains("\r") || value.contains("\n")) throw new IllegalArgumentException();
        InternetAddress address = new InternetAddress(value, true);
        address.validate();
        if (!address.getAddress().equals(value) || !value.contains("@")) throw new IllegalArgumentException();
    }
}
