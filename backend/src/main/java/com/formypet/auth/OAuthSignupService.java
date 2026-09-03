package com.formypet.auth;

import com.formypet.auth.client.KakaoUserInfo;
import com.formypet.auth.domain.OAuthAccount;
import com.formypet.auth.domain.User;
import com.formypet.auth.repository.OAuthAccountRepository;
import com.formypet.auth.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class OAuthSignupService {

    private static final String KAKAO_PROVIDER = "KAKAO";

    private final UserRepository userRepository;
    private final OAuthAccountRepository oauthAccountRepository;
    private final PasswordEncoder passwordEncoder;

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public User signupKakaoUser(KakaoUserInfo kakaoUser) {
        String email = resolveEmail(kakaoUser);
        String nickname = resolveNickname(kakaoUser);
        String randomSecret = UUID.randomUUID() + ":" + UUID.randomUUID();
        User user = User.createOAuth(email, passwordEncoder.encode(randomSecret), nickname, KAKAO_PROVIDER);
        userRepository.save(user);
        oauthAccountRepository.save(OAuthAccount.create(user, KAKAO_PROVIDER, kakaoUser.id()));
        log.info("Kakao signup: providerUserId={}", kakaoUser.id());
        return user;
    }

    private String resolveEmail(KakaoUserInfo kakaoUser) {
        String email = kakaoUser.email();
        if (kakaoUser.emailVerified()
                && email != null
                && !email.isBlank()
                && !userRepository.existsByEmail(email)) {
            return email;
        }
        return "kakao_" + kakaoUser.id() + "@oauth.kakao.local";
    }

    private String resolveNickname(KakaoUserInfo kakaoUser) {
        String nickname = kakaoUser.nickname();
        if (nickname == null || nickname.isBlank()) {
            return "Kakao User";
        }
        return nickname;
    }
}
