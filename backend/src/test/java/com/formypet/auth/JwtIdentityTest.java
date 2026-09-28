package com.formypet.auth;

import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.core.context.SecurityContextHolder;
import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.*;

class JwtIdentityTest {
    @Test
    void tokenExpiringBetweenValidationAndClaimReadIsAnonymous() throws Exception {
        JwtService jwt = mock(JwtService.class);
        when(jwt.isValid("expired-during-check")).thenReturn(true);
        when(jwt.extractUserId("expired-during-check"))
                .thenThrow(new io.jsonwebtoken.ExpiredJwtException(null, null, "Expired"));
        var request = new MockHttpServletRequest("GET", "/api/v1/users/me");
        request.addHeader("Authorization", "Bearer expired-during-check");
        SecurityContextHolder.clearContext();
        try {
            new JwtAuthFilter(jwt, mock(SessionGuard.class)).doFilter(request,
                    new MockHttpServletResponse(), (req, res) -> {});
            assertThat(SecurityContextHolder.getContext().getAuthentication()).isNull();
        } finally { SecurityContextHolder.clearContext(); }
    }

    @Test
    void currentTokenCarriesStableAccountIdentityAndSessionVersion() throws Exception {
        JwtService jwt = new JwtService("identity-test-only-not-a-production-key-000000000000", 60000);
        String token = jwt.generateAccessToken(17, 3);
        assertThat(jwt.extractUserId(token)).isEqualTo(17);
        assertThat(jwt.extractVersion(token)).isEqualTo(3);
        SessionGuard sessions = mock(SessionGuard.class);
        when(sessions.accepts(17, 3)).thenReturn(true);
        var request = new MockHttpServletRequest("GET", "/api/v1/users/me");
        request.addHeader("Authorization", "Bearer " + token);
        try {
            new JwtAuthFilter(jwt, sessions).doFilter(request, new MockHttpServletResponse(), (req, res) -> {});
            assertThat(SecurityContextHolder.getContext().getAuthentication().getPrincipal())
                    .isEqualTo(new AuthenticatedUser(17, 3));
        } finally { SecurityContextHolder.clearContext(); }
    }

    @Test
    void deletedOrRevokedIdentityIsAnonymous() throws Exception {
        JwtService jwt = new JwtService("identity-test-only-not-a-production-key-000000000000", 60000);
        var request = new MockHttpServletRequest("GET", "/api/v1/users/me");
        request.addHeader("Authorization", "Bearer " + jwt.generateAccessToken(17, 3));
        SecurityContextHolder.clearContext();
        try {
            new JwtAuthFilter(jwt, mock(SessionGuard.class)).doFilter(request, new MockHttpServletResponse(), (req, res) -> {});
            assertThat(SecurityContextHolder.getContext().getAuthentication()).isNull();
        } finally { SecurityContextHolder.clearContext(); }
    }

    @Test
    void legacyEmailOnlyTokenMustNotAuthenticate() throws Exception {
        JwtService jwt = new JwtService("identity-test-only-not-a-production-key-000000000000", 60000);
        SessionGuard sessions = mock(SessionGuard.class);
        when(sessions.accepts(anyLong(), anyLong())).thenReturn(true);
        var request = new MockHttpServletRequest("GET", "/api/v1/users/me");
        String legacy = io.jsonwebtoken.Jwts.builder().subject("same@example.test").claim("av", 0)
                .signWith(io.jsonwebtoken.security.Keys.hmacShaKeyFor(
                        "identity-test-only-not-a-production-key-000000000000".getBytes(java.nio.charset.StandardCharsets.UTF_8))).compact();
        request.addHeader("Authorization", "Bearer " + legacy);
        SecurityContextHolder.clearContext();
        try {
            new JwtAuthFilter(jwt, sessions).doFilter(request, new MockHttpServletResponse(), (req, res) -> {});
            assertThat(SecurityContextHolder.getContext().getAuthentication()).isNull();
        } finally {
            SecurityContextHolder.clearContext();
        }
    }
}
