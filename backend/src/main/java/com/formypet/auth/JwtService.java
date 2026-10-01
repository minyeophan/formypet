package com.formypet.auth;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Date;

@Service
public class JwtService {

    private final SecretKey key;
    private final long accessTokenExpiration;

    public JwtService(
            @Value("${app.jwt.secret}") String secret,
            @Value("${app.jwt.access-token-expiration}") long accessTokenExpiration
    ) {
        this.key = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
        this.accessTokenExpiration = accessTokenExpiration;
    }

    public String generateAccessToken(long userId, long version) {
        new AuthenticatedUser(userId, version);
        long now = System.currentTimeMillis();
        return Jwts.builder()
                .subject(Long.toString(userId))
                .claim("uid", userId)
                .claim("av", version)
                .issuedAt(new Date(now))
                .expiration(new Date(now + accessTokenExpiration))
                .signWith(key)
                .compact();
    }

    public long extractUserId(String token) {
        Claims claims = parseClaims(token);
        Object value = claims.get("uid");
        if (!(value instanceof Number number) || number.longValue() <= 0
                || number.doubleValue() != number.longValue()
                || !Long.toString(number.longValue()).equals(claims.getSubject())) {
            throw new IllegalArgumentException("Invalid account identity");
        }
        return number.longValue();
    }

    public long extractVersion(String token) {
        Object value = parseClaims(token).get("av");
        if (!(value instanceof Number number) || number.longValue() < 0
                || number.doubleValue() != number.longValue()) throw new IllegalArgumentException("Invalid session version");
        return number.longValue();
    }

    public boolean isValid(String token) {
        try {
            parseClaims(token);
            return true;
        } catch (JwtException | IllegalArgumentException e) {
            return false;
        }
    }

    private Claims parseClaims(String token) {
        return Jwts.parser()
                .verifyWith(key)
                .build()
                .parseSignedClaims(token)
                .getPayload();
    }
}
