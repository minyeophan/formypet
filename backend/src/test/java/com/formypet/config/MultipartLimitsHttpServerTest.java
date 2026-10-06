package com.formypet.config;

import org.junit.jupiter.api.Test;
import org.springframework.boot.autoconfigure.EnableAutoConfiguration;
import org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import com.formypet.common.exception.GlobalExceptionHandler;
import org.springframework.context.annotation.Import;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.test.context.TestPropertySource;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest(
        classes = MultipartLimitsHttpServerTest.TestApplication.class,
        webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
        properties = {
                "spring.servlet.multipart.max-file-size=5MB",
                "spring.servlet.multipart.max-request-size=26MB",
                "spring.servlet.multipart.file-size-threshold=0B"
        })
@TestPropertySource(properties = "server.tomcat.max-http-form-post-size=32MB")
class MultipartLimitsHttpServerTest {

    private static final String BOUNDARY = "FormypetMultipartBoundary7MA4YWxkTrZu0gW";
    private static final int MAX_FILE_BYTES = 5 * 1024 * 1024;

    @LocalServerPort int port;

    @Test
    void actualTomcatAcceptsFiveFilesAndPayload() throws Exception {
        HttpResponse<String> response = post(multipart(5, 16, 0));

        assertThat(response.statusCode()).isEqualTo(HttpStatus.OK.value());
        assertThat(response.body()).contains("files=5;caption=note");
    }

    @Test
    void actualTomcatAcceptsTenMultipartPartsAtTheBoundary() throws Exception {
        HttpResponse<String> response = post(multipart(9, 1, 0));

        assertThat(response.statusCode()).isEqualTo(HttpStatus.OK.value());
        assertThat(response.body()).contains("files=9;caption=note");
    }

    @Test
    void actualTomcatRejectsMoreThanTenPartsWithClientError() throws Exception {
        HttpResponse<String> response = post(multipart(10, 1, 0));

        assertThat(response.statusCode()).isBetween(400, 499);
        assertThat(response.body()).doesNotContain("FileCountLimitExceededException");
    }

    @Test
    void actualTomcatRejectsOversizedPartHeaders() throws Exception {
        HttpResponse<String> response = post(multipart(1, 1, 2200));

        assertThat(response.statusCode()).isBetween(400, 499);
    }

    @Test
    void actualTomcatRejectsFilesOverFiveMebibytes() throws Exception {
        HttpResponse<String> response = post(multipart(1, MAX_FILE_BYTES + 1, 0));

        assertThat(response.statusCode()).isBetween(400, 499);
    }

    @Test
    void actualTomcatRejectsRequestsOverTwentySixMebibytes() throws Exception {
        assertThat(post(multipart(1, 1, 0)).statusCode()).isEqualTo(HttpStatus.OK.value());

        try {
            HttpResponse<String> response = post(multipart(6, MAX_FILE_BYTES, 0));
            assertThat(response.statusCode()).isBetween(400, 499);
        } catch (IOException connectionClosedByTomcat) {
            // Tomcat may reset the connection while rejecting a request over the configured size limit.
        }
    }

    private HttpResponse<String> post(byte[] body) throws IOException, InterruptedException {
        HttpRequest request = HttpRequest.newBuilder(URI.create("http://localhost:" + port + "/multipart-test"))
                .header("Content-Type", "multipart/form-data; boundary=" + BOUNDARY)
                .POST(HttpRequest.BodyPublishers.ofByteArray(body))
                .build();
        return HttpClient.newHttpClient().send(request, HttpResponse.BodyHandlers.ofString());
    }

    private byte[] multipart(int fileCount, int fileBytes, int extraHeaderBytes) throws IOException {
        ByteArrayOutputStream body = new ByteArrayOutputStream();
        byte[] contents = new byte[fileBytes];
        for (int i = 0; i < fileCount; i++) {
            String filename = "photo" + "x".repeat(extraHeaderBytes) + i + ".png";
            write(body, "--" + BOUNDARY + "\r\n"
                    + "Content-Disposition: form-data; name=\"files\"; filename=\"" + filename + "\"\r\n"
                    + "Content-Type: image/png\r\n\r\n");
            body.write(contents);
            write(body, "\r\n");
        }
        write(body, "--" + BOUNDARY + "\r\n"
                + "Content-Disposition: form-data; name=\"caption\"\r\n\r\n"
                + "note\r\n--" + BOUNDARY + "--\r\n");
        return body.toByteArray();
    }

    private void write(ByteArrayOutputStream body, String value) throws IOException {
        body.write(value.getBytes(StandardCharsets.UTF_8));
    }

    @Configuration(proxyBeanMethods = false)
    @EnableAutoConfiguration(exclude = DataSourceAutoConfiguration.class)
    @Import({MultipartLimitsConfiguration.class, MultipartTestController.class, TestSecurityConfiguration.class,
            GlobalExceptionHandler.class})
    static class TestApplication {}

    @Configuration(proxyBeanMethods = false)
    static class TestSecurityConfiguration {
        @Bean
        SecurityFilterChain testSecurity(HttpSecurity http) throws Exception {
            return http.authorizeHttpRequests(requests -> requests.anyRequest().permitAll())
                    .csrf(csrf -> csrf.disable())
                    .build();
        }
    }

    @RestController
    static class MultipartTestController {
        @PostMapping(path = "/multipart-test", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
        ResponseEntity<String> accept(@RequestPart List<MultipartFile> files, @RequestPart String caption) {
            return ResponseEntity.ok("files=" + files.size() + ";caption=" + caption);
        }
    }
}
