package com.formypet.domain.user.service.impl;

import com.formypet.domain.user.dto.request.AccountDeletionRequest;
import com.formypet.domain.user.dto.response.AccountDeletionReceipt;
import com.formypet.domain.user.service.AccountDeletionService;
import com.formypet.domain.user.service.AccountDeletionTransaction;

import com.formypet.domain.auth.security.SessionGuard;
import com.formypet.domain.auth.client.KakaoUserClient;
import com.formypet.domain.auth.client.KakaoUserInfo;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class AccountDeletionServiceImpl implements AccountDeletionService {
    private final SessionGuard sessions;
    private final KakaoUserClient kakao;
    private final AccountDeletionTransaction deletion;

    public AccountDeletionReceipt delete(Long actorId, AccountDeletionRequest request) {
        com.formypet.domain.auth.entity.SessionSnapshot account = sessions.find(actorId).orElseThrow(SessionGuard::invalid);
        if ("LOCAL".equals(account.source())) {
            if (request.password() == null || request.password().isBlank()
                    || request.kakaoAccessToken() != null) throw SessionGuard.invalid();
            return deletion.delete(actorId, request.password(), null);
        }
        if (!"KAKAO".equals(account.source()) || request.kakaoAccessToken() == null
                || request.kakaoAccessToken().isBlank() || request.password() != null) {
            throw SessionGuard.invalid();
        }
        KakaoUserInfo identity = kakao.fetchUser(request.kakaoAccessToken());
        return deletion.delete(actorId, null, identity.id());
    }
}
