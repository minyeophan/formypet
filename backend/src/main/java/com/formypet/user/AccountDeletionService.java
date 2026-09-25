package com.formypet.user;

import com.formypet.auth.SessionGuard;
import com.formypet.auth.client.KakaoUserClient;
import com.formypet.auth.client.KakaoUserInfo;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class AccountDeletionService {
    private final SessionGuard sessions;
    private final KakaoUserClient kakao;
    private final AccountDeletionTransaction deletion;

    public AccountDeletionReceipt delete(String email, AccountDeletionRequest request) {
        SessionGuard.Snapshot account = sessions.find(email).orElseThrow(SessionGuard::invalid);
        if ("LOCAL".equals(account.source())) {
            if (request.password() == null || request.password().isBlank()
                    || request.kakaoAccessToken() != null) throw SessionGuard.invalid();
            return deletion.delete(email, request.password(), null);
        }
        if (!"KAKAO".equals(account.source()) || request.kakaoAccessToken() == null
                || request.kakaoAccessToken().isBlank() || request.password() != null) {
            throw SessionGuard.invalid();
        }
        KakaoUserInfo identity = kakao.fetchUser(request.kakaoAccessToken());
        return deletion.delete(email, null, identity.id());
    }
}
