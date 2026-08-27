package com.petyilgi.auth.client;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.web.client.RestClient;

import java.io.IOException;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.test.web.client.ExpectedCount.once;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.header;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.requestTo;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withStatus;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withSuccess;

class RestClientKakaoUserClientTest {

    private MockRestServiceServer server;
    private RestClientKakaoUserClient client;

    @BeforeEach
    void setUp() {
        RestClient.Builder builder = RestClient.builder();
        server = MockRestServiceServer.bindTo(builder).build();
        client = new RestClientKakaoUserClient(builder);
    }

    @Test
    void fetchUserParsesNormalResponse() {
        server.expect(once(), requestTo("https://kapi.kakao.com/v2/user/me"))
                .andExpect(header(HttpHeaders.AUTHORIZATION, "Bearer access-token"))
                .andRespond(withSuccess("""
                        {
                          "id": 12345,
                          "kakao_account": {
                            "email": "kakao@example.com",
                            "is_email_verified": true,
                            "profile": {
                              "nickname": "kakao-user"
                            }
                          }
                        }
                        """, MediaType.APPLICATION_JSON));

        KakaoUserInfo user = client.fetchUser("access-token");

        assertThat(user.id()).isEqualTo("12345");
        assertThat(user.email()).isEqualTo("kakao@example.com");
        assertThat(user.emailVerified()).isTrue();
        assertThat(user.nickname()).isEqualTo("kakao-user");
        server.verify();
    }

    @Test
    void fetchUserAllowsMissingEmailAndNickname() {
        server.expect(once(), requestTo("https://kapi.kakao.com/v2/user/me"))
                .andRespond(withSuccess("""
                        {
                          "id": 12346,
                          "kakao_account": {}
                        }
                        """, MediaType.APPLICATION_JSON));

        KakaoUserInfo user = client.fetchUser("access-token");

        assertThat(user.id()).isEqualTo("12346");
        assertThat(user.email()).isNull();
        assertThat(user.emailVerified()).isFalse();
        assertThat(user.nickname()).isNull();
    }

    @Test
    void fetchUserConvertsKakao401ToBadCredentials() {
        server.expect(once(), requestTo("https://kapi.kakao.com/v2/user/me"))
                .andRespond(withStatus(HttpStatus.UNAUTHORIZED));

        assertThatThrownBy(() -> client.fetchUser("bad-token"))
                .isInstanceOf(BadCredentialsException.class);
    }

    @Test
    void fetchUserConvertsKakao5xxToBadCredentials() {
        server.expect(once(), requestTo("https://kapi.kakao.com/v2/user/me"))
                .andRespond(withStatus(HttpStatus.INTERNAL_SERVER_ERROR));

        assertThatThrownBy(() -> client.fetchUser("bad-token"))
                .isInstanceOf(BadCredentialsException.class);
    }

    @Test
    void fetchUserConvertsNetworkFailureToBadCredentials() {
        server.expect(once(), requestTo("https://kapi.kakao.com/v2/user/me"))
                .andRespond(request -> { throw new IOException("Connection refused"); });

        assertThatThrownBy(() -> client.fetchUser("access-token"))
                .isInstanceOf(BadCredentialsException.class)
                .hasMessageContaining("카카오 서비스가 일시적으로 불안정합니다.");
        server.verify();
    }

    @Test
    void fetchUserPreservesInvalidResponseAsBadCredentials() {
        server.expect(once(), requestTo("https://kapi.kakao.com/v2/user/me"))
                .andRespond(withSuccess("{}", MediaType.APPLICATION_JSON));

        assertThatThrownBy(() -> client.fetchUser("access-token"))
                .isInstanceOf(BadCredentialsException.class)
                .hasMessage("Invalid Kakao user response");
    }
}
