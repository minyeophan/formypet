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
import java.nio.file.Files;
import java.nio.file.Path;

@Configuration
public class FirebaseConfiguration {
    private static final Logger log = LoggerFactory.getLogger(FirebaseConfiguration.class);

    @Value("${app.firebase.credentials-path:firebase-service-account.json}")
    private String credentialsPath;

    @PostConstruct
    void initialize() {
        if (!FirebaseApp.getApps().isEmpty()) return;
        Path path = Path.of(credentialsPath);
        if (!Files.isRegularFile(path)) {
            log.warn("Firebase credentials file not found; push notifications are disabled: {}", path);
            return;
        }
        try (FileInputStream serviceAccount = new FileInputStream(path.toFile())) {
            FirebaseOptions options = FirebaseOptions.builder()
                    .setCredentials(GoogleCredentials.fromStream(serviceAccount))
                    .build();
            FirebaseApp.initializeApp(options);
            log.info("Firebase Admin SDK initialized");
        } catch (Exception error) {
            log.error("Firebase Admin SDK initialization failed", error);
        }
    }
}
