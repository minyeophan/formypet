package com.formypet.auth;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.lang.NonNull;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.List;

@Component
@RequiredArgsConstructor
public class JwtAuthFilter extends OncePerRequestFilter {

    private final JwtService jwtService;
    private final SessionGuard sessions;

    @Override
    protected void doFilterInternal(@NonNull HttpServletRequest request,
                                    @NonNull HttpServletResponse response,
                                    @NonNull FilterChain filterChain) throws ServletException, IOException {
        String header = request.getHeader("Authorization");
        String path = request.getServletPath();
        if (path.startsWith("/api/v1/auth/") || path.equals("/api/v1/public/policies")
                || path.startsWith("/api/v1/public/policies/") || path.equals("/privacy")
                || path.equals("/terms") || path.startsWith("/policies/")) {
            filterChain.doFilter(request, response);
            return;
        }
        if (header != null && header.startsWith("Bearer ")) {
            String token = header.substring(7);
            if (jwtService.isValid(token)) {
                try {
                    long userId = jwtService.extractUserId(token);
                    long version = jwtService.extractVersion(token);
                    if (sessions.accepts(userId, version)) {
                        var auth = new UsernamePasswordAuthenticationToken(new AuthenticatedUser(userId, version), null, List.of());
                        SecurityContextHolder.getContext().setAuthentication(auth);
                    }
                } catch (io.jsonwebtoken.JwtException | IllegalArgumentException ignored) {
                    // An invalid session is anonymous; protected routes return 401.
                }
            }
        }
        filterChain.doFilter(request, response);
    }
}
