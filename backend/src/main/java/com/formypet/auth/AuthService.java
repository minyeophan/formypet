package com.formypet.auth;

import com.formypet.auth.client.KakaoUserClient;
import com.formypet.auth.client.KakaoUserInfo;
import com.formypet.auth.domain.RefreshToken;
import com.formypet.auth.domain.User;
import com.formypet.auth.dto.KakaoLoginRequest;
import com.formypet.auth.dto.LoginRequest;
import com.formypet.auth.dto.RegisterRequest;
import com.formypet.auth.dto.TokenResponse;
import com.formypet.auth.repository.OAuthAccountRepository;
import com.formypet.auth.repository.RefreshTokenRepository;
import com.formypet.auth.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final OAuthAccountRepository oauthAccountRepository;
    private final JwtService jwtService;
    private final PasswordEncoder passwordEncoder;
    private final KakaoUserClient kakaoUserClient;
    private final OAuthSignupService oauthSignupService;
    private final SessionGuard sessions;
    private final org.springframework.jdbc.core.JdbcTemplate jdbc;
    private final org.springframework.transaction.support.TransactionTemplate transactions;

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
        SessionGuard.Snapshot snapshot;
        try {
            snapshot = sessions.lock(request.email());
        } catch (BadCredentialsException invalid) {
            throw new BadCredentialsException("이메일 또는 비밀번호가 올바르지 않습니다.");
        }
        User user = userRepository.findByEmail(request.email())
                .orElseThrow(() -> new BadCredentialsException("이메일 또는 비밀번호가 올바르지 않습니다."));
        if (!"LOCAL".equals(snapshot.source())) {
            throw new BadCredentialsException("이메일 또는 비밀번호가 올바르지 않습니다.");
        }
        if (!passwordEncoder.matches(request.password(), snapshot.passwordHash())) {
            throw new BadCredentialsException("이메일 또는 비밀번호가 올바르지 않습니다.");
        }
        return issueTokens(user, snapshot.version());
    }

    // @Transactional 없음: fetchUser() 외부 HTTP 호출을 DB 트랜잭션 안에 묶으면 커넥션 점유 위험
    public TokenResponse kakaoLogin(KakaoLoginRequest request) {
        KakaoUserInfo kakaoUser = kakaoUserClient.fetchUser(request.accessToken());
        User user = oauthAccountRepository.findByProviderAndProviderUserId("KAKAO", kakaoUser.id())
                .map(account -> {
                    log.debug("Kakao login: userId={}", account.getUser().getId());
                    return account.getUser();
                })
                .orElseGet(() -> signupOrReloadKakaoUser(kakaoUser));
        return transactions.execute(status -> {
            var current = sessions.lock(user.getId());
            return issueTokens(user, current.version());
        });
    }

    private User signupOrReloadKakaoUser(KakaoUserInfo kakaoUser) {
        try {
            return oauthSignupService.signupKakaoUser(kakaoUser);
        } catch (DataIntegrityViolationException ex) {
            return oauthAccountRepository.findByProviderAndProviderUserId("KAKAO", kakaoUser.id())
                    .map(account -> account.getUser())
                    .orElseThrow(() -> new OAuthLoginConflictException("OAuth login conflict"));
        }
    }

    @Transactional
    public TokenResponse refresh(String rawRefreshToken) {
        var owners = jdbc.queryForList("SELECT user_id FROM refresh_tokens WHERE token=?", Long.class, rawRefreshToken);
        if (owners.isEmpty()) throw SessionGuard.invalid();
        var snapshot = sessions.lock(owners.getFirst());
        // A reset may have deleted the token while we waited for the user lock.
        if (jdbc.queryForList("SELECT id FROM refresh_tokens WHERE token=? AND user_id=? FOR UPDATE", Long.class,
                rawRefreshToken, snapshot.id()).isEmpty()) throw SessionGuard.invalid();
        RefreshToken stored = refreshTokenRepository.findByToken(rawRefreshToken)
                .orElseThrow(() -> new BadCredentialsException("유효하지 않은 Refresh Token입니다."));
        if (stored.isExpired()) {
            refreshTokenRepository.delete(stored);
            throw new BadCredentialsException("만료된 Refresh Token입니다.");
        }
        refreshTokenRepository.delete(stored); // 토큰 로테이션
        refreshTokenRepository.flush();
        return issueTokens(stored.getUser(), snapshot.version());
    }

    @Transactional
    public void logout(String rawRefreshToken) {
        refreshTokenRepository.findByToken(rawRefreshToken)
                .ifPresent(refreshTokenRepository::delete);
    }

    private TokenResponse issueTokens(User user) {
        return issueTokens(user, sessions.lock(user.getId()).version());
    }

    private TokenResponse issueTokens(User user, long version) {
        String accessToken  = jwtService.generateAccessToken(user.getEmail(), version);
        String refreshToken = UUID.randomUUID().toString();
        LocalDateTime expiresAt = LocalDateTime.now().plusSeconds(refreshTokenExpiration / 1000);
        refreshTokenRepository.save(RefreshToken.create(user, refreshToken, expiresAt));
        return TokenResponse.of(accessToken, refreshToken);
    }
}
