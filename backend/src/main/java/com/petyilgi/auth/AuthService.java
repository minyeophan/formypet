package com.petyilgi.auth;

import com.petyilgi.auth.domain.RefreshToken;
import com.petyilgi.auth.domain.User;
import com.petyilgi.auth.dto.LoginRequest;
import com.petyilgi.auth.dto.RegisterRequest;
import com.petyilgi.auth.dto.TokenResponse;
import com.petyilgi.auth.repository.RefreshTokenRepository;
import com.petyilgi.auth.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final JwtService jwtService;
    private final PasswordEncoder passwordEncoder;

    @Value("${app.jwt.refresh-token-expiration}")
    private long refreshTokenExpiration;

    @Transactional
    public TokenResponse register(RegisterRequest request) {
        if (userRepository.existsByEmail(request.email())) {
            throw new IllegalArgumentException("이미 사용 중인 이메일입니다.");
        }
        User user = User.create(request.email(), passwordEncoder.encode(request.password()), request.nickname());
        userRepository.save(user);
        return issueTokens(user);
    }

    @Transactional
    public TokenResponse login(LoginRequest request) {
        User user = userRepository.findByEmail(request.email())
                .orElseThrow(() -> new BadCredentialsException("이메일 또는 비밀번호가 올바르지 않습니다."));
        if (!passwordEncoder.matches(request.password(), user.getPasswordHash())) {
            throw new BadCredentialsException("이메일 또는 비밀번호가 올바르지 않습니다.");
        }
        return issueTokens(user);
    }

    @Transactional
    public TokenResponse refresh(String rawRefreshToken) {
        RefreshToken stored = refreshTokenRepository.findByToken(rawRefreshToken)
                .orElseThrow(() -> new BadCredentialsException("유효하지 않은 Refresh Token입니다."));
        if (stored.isExpired()) {
            refreshTokenRepository.delete(stored);
            throw new BadCredentialsException("만료된 Refresh Token입니다.");
        }
        refreshTokenRepository.delete(stored); // 토큰 로테이션
        return issueTokens(stored.getUser());
    }

    @Transactional
    public void logout(String rawRefreshToken) {
        refreshTokenRepository.findByToken(rawRefreshToken)
                .ifPresent(refreshTokenRepository::delete);
    }

    private TokenResponse issueTokens(User user) {
        String accessToken  = jwtService.generateAccessToken(user.getEmail());
        String refreshToken = UUID.randomUUID().toString();
        LocalDateTime expiresAt = LocalDateTime.now().plusSeconds(refreshTokenExpiration / 1000);
        refreshTokenRepository.save(RefreshToken.create(user, refreshToken, expiresAt));
        return TokenResponse.of(accessToken, refreshToken);
    }
}
