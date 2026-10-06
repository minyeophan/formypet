package com.formypet.common.ratelimit;

import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;

import static org.assertj.core.api.Assertions.assertThat;

class ClientAddressResolverTest {
    @Test
    void usesRailwayRealIpOnlyWhenRailwayPublicDomainIsPresent() {
        MockHttpServletRequest request = request("10.0.0.5", "198.51.100.21");

        assertThat(new ClientAddressResolver("formypet-production.up.railway.app").resolve(request))
                .isEqualTo("198.51.100.21");
        assertThat(new ClientAddressResolver("").resolve(request)).isEqualTo("10.0.0.5");
    }

    @Test
    void rejectsMalformedAndChainedRailwayHeaders() {
        ClientAddressResolver resolver = new ClientAddressResolver("formypet-production.up.railway.app");

        assertThat(resolver.resolve(request("10.0.0.5", "not-an-ip"))).isEqualTo("10.0.0.5");
        assertThat(resolver.resolve(request("10.0.0.5", "198.51.100.21, 203.0.113.8")))
                .isEqualTo("10.0.0.5");
    }

    @Test
    void acceptsIpv6RailwayClientAddress() {
        assertThat(new ClientAddressResolver("formypet-production.up.railway.app")
                .resolve(request("10.0.0.5", "2001:db8::21"))).isEqualTo("2001:db8::21");
    }

    private MockHttpServletRequest request(String remoteAddress, String railwayRealIp) {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setRemoteAddr(remoteAddress);
        request.addHeader("X-Real-IP", railwayRealIp);
        return request;
    }
}
