package com.formypet.user;

import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.util.UriComponentsBuilder;
import org.springframework.web.client.RestClient;
import org.springframework.core.ParameterizedTypeReference;

import java.util.Map;
import java.util.List;

@Component
@RequiredArgsConstructor
public class RestKakaoAccountUnlinker implements KakaoAccountUnlinker {
    private final RestClient.Builder restClientBuilder;

    @Value("${app.account-deletion.kakao-admin-key:}")
    private String adminKey;

    @Override
    public boolean isConfigured() {
        return adminKey != null && !adminKey.isBlank();
    }

    @Override
    public void unlink(String providerUserId) {
        if (!isConfigured()) throw new IllegalStateException("Kakao unlink is not configured");
        long id;
        try {
            id = Long.parseLong(providerUserId);
        } catch (NumberFormatException invalidId) {
            throw new IllegalArgumentException("Invalid Kakao user identifier");
        }
        RestClient client = restClientBuilder.build();
        List<Map<String, Object>> connectedUsers = client.get()
                .uri(UriComponentsBuilder.fromUriString("https://kapi.kakao.com/v2/app/users")
                        .queryParam("target_id_type", "user_id")
                        .queryParam("target_ids", "[" + id + "]")
                        .build().encode().toUri())
                .header("Authorization", "KakaoAK " + adminKey)
                .retrieve()
                .body(new ParameterizedTypeReference<>() {});
        if (connectedUsers == null) throw new IllegalStateException("Kakao user lookup returned no response");
        boolean connected = connectedUsers.stream().anyMatch(user -> user.get("id") instanceof Number value
                && value.longValue() == id);
        if (!connected) return; // A previous unlink may have succeeded before its response was lost.

        MultiValueMap<String, String> form = new LinkedMultiValueMap<>();
        form.add("target_id_type", "user_id");
        form.add("target_id", Long.toString(id));
        Map<?, ?> response = client.post()
                .uri("https://kapi.kakao.com/v1/user/unlink")
                .header("Authorization", "KakaoAK " + adminKey)
                .contentType(MediaType.APPLICATION_FORM_URLENCODED)
                .body(form)
                .retrieve()
                .body(Map.class);
        if (response == null || !(response.get("id") instanceof Number returned)
                || returned.longValue() != id) {
            throw new IllegalStateException("Kakao unlink response did not match the requested account");
        }
    }
}
