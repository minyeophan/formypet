package com.formypet.domain.auth.service.impl;

import com.formypet.domain.auth.service.OAuthSignupService;

import com.formypet.domain.auth.client.KakaoUserInfo;
import com.formypet.domain.auth.entity.OAuthAccount;
import com.formypet.domain.user.entity.User;
import com.formypet.domain.auth.repository.OAuthAccountRepository;
import com.formypet.domain.user.repository.UserRepository;
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
public class OAuthSignupServiceImpl implements OAuthSignupService {

    private static final String KAKAO_PROVIDER = "KAKAO";

    private final UserRepository userRepository;
    private final OAuthAccountRepository oauthAccountRepository;
    private final PasswordEncoder passwordEncoder;

    @Transactional(propagation = Propagation.MANDATORY)
    public User signupKakaoUser(KakaoUserInfo kakaoUser) {
        String email = resolveEmail(kakaoUser);
        String nickname = resolveNickname(kakaoUser);
        // BCrypt accepts at most 72 input bytes; UUIDs are ASCII, so two fit exactly.
        String randomSecret = UUID.randomUUID().toString() + UUID.randomUUID();
        User user = User.createOAuth(email, passwordEncoder.encode(randomSecret), nickname, KAKAO_PROVIDER);
        userRepository.save(user);
        oauthAccountRepository.save(OAuthAccount.create(user, KAKAO_PROVIDER, kakaoUser.id()));
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
