package com.formypet.config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;

import jakarta.annotation.PostConstruct;
import java.io.FileInputStream;
import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

@Configuration
public class FirebaseConfiguration {
    private static final Logger log = LoggerFactory.getLogger(FirebaseConfiguration.class);

    @Value("${app.firebase.credentials-path:firebase-service-account.json}")
    private String credentialsPath;

    @Value("${app.firebase.credentials-json:}")
    private String credentialsJson;

    @PostConstruct
    void initialize() {
        if (!FirebaseApp.getApps().isEmpty()) return;
        boolean inline = credentialsJson != null && !credentialsJson.isBlank();
        if (!inline && !Files.isRegularFile(Path.of(credentialsPath))) {
            log.warn("Firebase credentials not configured; push notifications are disabled");
            return;
        }
        try (InputStream serviceAccount = inline
                ? new ByteArrayInputStream(credentialsJson.getBytes(StandardCharsets.UTF_8))
                : new FileInputStream(credentialsPath)) {
            FirebaseOptions options = FirebaseOptions.builder()
                    .setCredentials(GoogleCredentials.fromStream(serviceAccount))
                    .build();
            FirebaseApp.initializeApp(options);
            log.info("Firebase Admin SDK initialized");
        } catch (Exception error) {
            // Parser exception messages can contain credential JSON. Never attach the cause.
            throw new IllegalStateException("Firebase credentials are invalid; check the configured secret or file");
        }
    }
}
