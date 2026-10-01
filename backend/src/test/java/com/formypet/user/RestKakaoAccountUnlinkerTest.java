package com.formypet.user;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.web.client.RestClient;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.client.ExpectedCount.once;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.header;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.method;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.requestTo;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.content;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withSuccess;
import static org.springframework.http.HttpMethod.GET;
import static org.springframework.http.HttpMethod.POST;

class RestKakaoAccountUnlinkerTest {
    private MockRestServiceServer server;
    private RestKakaoAccountUnlinker unlinker;

    @BeforeEach
    void setUp() {
        RestClient.Builder builder = RestClient.builder();
        server = MockRestServiceServer.bindTo(builder).build();
        unlinker = new RestKakaoAccountUnlinker(builder);
        ReflectionTestUtils.setField(unlinker, "adminKey", "server-admin-key");
    }

    @Test
    void unlinksConnectedUserWithAdminKey() {
        server.expect(once(), requestTo("https://kapi.kakao.com/v2/app/users?target_id_type=user_id&target_ids=%5B12345%5D"))
                .andExpect(method(GET))
                .andExpect(header(HttpHeaders.AUTHORIZATION, "KakaoAK server-admin-key"))
                .andRespond(withSuccess("[{\"id\":12345}]", MediaType.APPLICATION_JSON));
        server.expect(once(), requestTo("https://kapi.kakao.com/v1/user/unlink"))
                .andExpect(method(POST))
                .andExpect(header(HttpHeaders.AUTHORIZATION, "KakaoAK server-admin-key"))
                .andExpect(content().string("target_id_type=user_id&target_id=12345"))
                .andRespond(withSuccess("{\"id\":12345}", MediaType.APPLICATION_JSON));

        unlinker.unlink("12345");

        server.verify();
    }

    @Test
    void treatsAlreadyUnlinkedUserAsSuccessfulRetry() {
        server.expect(once(), requestTo("https://kapi.kakao.com/v2/app/users?target_id_type=user_id&target_ids=%5B12345%5D"))
                .andRespond(withSuccess("[]", MediaType.APPLICATION_JSON));

        unlinker.unlink("12345");

        server.verify();
    }

    @Test
    void reportsConfigurationOnlyWhenServerAdminKeyIsPresent() {
        assertThat(unlinker.isConfigured()).isTrue();
        ReflectionTestUtils.setField(unlinker, "adminKey", " ");
        assertThat(unlinker.isConfigured()).isFalse();
    }
}
