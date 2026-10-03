package com.formypet.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.google.firebase.FirebaseApp;
import java.io.PrintWriter;
import java.io.StringWriter;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.KeyPairGenerator;
import java.util.Base64;
import java.util.Map;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;

import static org.assertj.core.api.Assertions.assertThat;

class FirebaseConfigurationTest {
    @TempDir Path temp;

    @AfterEach
    void cleanFirebase() {
        FirebaseApp.getApps().forEach(FirebaseApp::delete);
    }

    private ApplicationContextRunner context() {
        return new ApplicationContextRunner().withUserConfiguration(FirebaseConfiguration.class)
                .withPropertyValues("app.firebase.credentials-path=" + temp.resolve("missing.json"));
    }

    @Test
    void initializesFromSecretJsonWithoutAFile() throws Exception {
        context().withPropertyValues("app.firebase.credentials-json=" + credentials("inline-project"))
                .run(ctx -> {
                    assertThat(ctx).hasNotFailed();
                    assertThat(FirebaseApp.getApps()).hasSize(1);
                });
    }

    @Test
    void keepsFileCredentialsWorking() throws Exception {
        Path file = temp.resolve("account.json");
        Files.writeString(file, credentials("file-project"));
        context().withPropertyValues("app.firebase.credentials-path=" + file).run(ctx -> {
            assertThat(ctx).hasNotFailed();
            assertThat(FirebaseApp.getApps()).hasSize(1);
        });
    }

    @Test
    void absentCredentialsDoNotBreakExistingNonPushDeployments() {
        context().run(ctx -> {
            assertThat(ctx).hasNotFailed();
            assertThat(FirebaseApp.getApps()).isEmpty();
        });
    }

    @Test
    void invalidExplicitCredentialsFailInsteadOfSilentlyDisablingPush() {
        context().withPropertyValues("app.firebase.credentials-json=invalid-test-secret")
                .run(ctx -> {
                    assertThat(ctx).hasFailed();
                    assertThat(ctx.getStartupFailure()).hasStackTraceContaining("Firebase credentials are invalid")
                            .hasStackTraceContaining("IllegalStateException");
                    assertThat(ctx.getStartupFailure()).hasStackTraceContaining("FirebaseConfiguration");
                    var trace = new StringWriter();
                    ctx.getStartupFailure().printStackTrace(new PrintWriter(trace));
                    assertThat(trace.toString()).doesNotContain("invalid-test-secret");
                });
    }

    private static String credentials(String project) throws Exception {
        var generator = KeyPairGenerator.getInstance("RSA");
        generator.initialize(2048);
        String pem = "-----BEGIN PRIVATE KEY-----\n"
                + Base64.getMimeEncoder(64, new byte[]{'\n'}).encodeToString(generator.generateKeyPair().getPrivate().getEncoded())
                + "\n-----END PRIVATE KEY-----\n";
        return new ObjectMapper().writeValueAsString(Map.of(
                "type", "service_account", "project_id", project, "private_key", pem,
                "private_key_id", "test-key", "client_id", "123456789",
                "client_email", "test@" + project + ".iam.gserviceaccount.com",
                "token_uri", "https://oauth2.googleapis.com/token"));
    }
}
