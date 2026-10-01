package com.formypet.auth.client;

import org.springframework.http.HttpHeaders;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.lang.Nullable;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientResponseException;

import java.time.Duration;
import java.util.Map;

@Component
public class RestClientKakaoUserClient implements KakaoUserClient {

    private static final String KAKAO_API_BASE_URL = "https://kapi.kakao.com";

    private final RestClient restClient;

    public RestClientKakaoUserClient() {
        this.restClient = RestClient.builder()
                .baseUrl(KAKAO_API_BASE_URL)
                .requestFactory(requestFactory())
                .build();
    }

    RestClientKakaoUserClient(RestClient.Builder builder) {
        this.restClient = builder
                .baseUrl(KAKAO_API_BASE_URL)
                .build();
    }

    @Override
    public KakaoUserInfo fetchUser(String accessToken) {
        try {
            Map<?, ?> body = restClient.get()
                    .uri("/v2/user/me")
                    .header(HttpHeaders.AUTHORIZATION, "Bearer " + accessToken)
                    .retrieve()
                    .body(Map.class);
            return parse(body);
        } catch (RestClientResponseException ex) {
            throw new BadCredentialsException("Invalid Kakao token", ex);
        } catch (BadCredentialsException ex) {
            throw ex;
        } catch (Exception ex) {
            throw new BadCredentialsException("카카오 서비스가 일시적으로 불안정합니다.", ex);
        }
    }

    private KakaoUserInfo parse(@Nullable Map<?, ?> body) {
        if (body == null || body.get("id") == null) {
            throw new BadCredentialsException("Invalid Kakao user response");
        }

        Map<?, ?> kakaoAccount = asMap(body.get("kakao_account"));
        Map<?, ?> profile = asMap(kakaoAccount.get("profile"));

        String id = String.valueOf(body.get("id"));
        String email = asString(kakaoAccount.get("email"));
        boolean emailVerified = Boolean.TRUE.equals(kakaoAccount.get("is_email_verified"));
        String nickname = asString(profile.get("nickname"));

        return new KakaoUserInfo(id, email, emailVerified, nickname);
    }

    private Map<?, ?> asMap(@Nullable Object value) {
        if (value instanceof Map<?, ?> map) {
            return map;
        }
        return Map.of();
    }

    @Nullable
    private String asString(@Nullable Object value) {
        return value instanceof String string && !string.isBlank() ? string : null;
    }

    private SimpleClientHttpRequestFactory requestFactory() {
        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(Duration.ofSeconds(3));
        factory.setReadTimeout(Duration.ofSeconds(5));
        return factory;
    }
}
