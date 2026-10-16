package com.formypet.domain.user.service.impl;

import com.formypet.domain.auth.security.OAuthLifecycleGuard;

import com.formypet.domain.user.dto.response.AccountDeletionReceipt;
import com.formypet.domain.user.service.AccountDeletionTransaction;

import com.formypet.domain.auth.security.SessionGuard;
import com.formypet.domain.auth.security.RecoveryCrypto;
import com.formypet.domain.user.repository.jdbc.AccountDeletionCommands;
import com.formypet.common.exception.ApiException;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.List;

@Service
@RequiredArgsConstructor
public class AccountDeletionTransactionImpl implements AccountDeletionTransaction {
    private final AccountDeletionCommands commands;
    private final SessionGuard sessions;
    private final com.formypet.domain.auth.security.OAuthLifecycleGuard oauthLifecycle;
    private final PasswordEncoder passwords;
    private final RecoveryCrypto recoveryCrypto;

    @Transactional
    public AccountDeletionReceipt delete(Long actorId, String password, String kakaoUserId) {
        if (kakaoUserId != null) oauthLifecycle.lock(kakaoUserId);
        com.formypet.domain.auth.entity.SessionSnapshot user = sessions.lockCurrent(actorId);
        if ("LOCAL".equals(user.source())) {
            if (password == null || !passwords.matches(password, user.passwordHash())) throw SessionGuard.invalid();
            if (kakaoUserId != null) throw SessionGuard.invalid();
        } else if ("KAKAO".equals(user.source())) {
            if (kakaoUserId == null || !commands.lockKakaoIdentity(user.id(), kakaoUserId)) throw SessionGuard.invalid();
        } else {
            throw SessionGuard.invalid();
        }
        return deleteAccountData(user, kakaoUserId, true);
    }

    /** Processes an external unlink without enqueueing another provider API call. */
    @Transactional(propagation = org.springframework.transaction.annotation.Propagation.MANDATORY)
    public void deleteAfterKakaoUnlink(String providerUserId) {
        oauthLifecycle.lock(providerUserId);
        List<Long> users = commands.lockKakaoUsers(providerUserId);
        if (users.isEmpty()) return;
        com.formypet.domain.auth.entity.SessionSnapshot user = sessions.lock(users.getFirst());
        if (!"KAKAO".equals(user.source())) {
            throw new IllegalStateException("Kakao account source does not match the unlink event");
        }
        deleteAccountData(user, providerUserId, false);
    }

    private AccountDeletionReceipt deleteAccountData(com.formypet.domain.auth.entity.SessionSnapshot user, String kakaoUserId,
                                                       boolean queueProviderUnlink) {
        List<Long> affectedPosts = commands.affectedPosts(user.id());
        List<Long> affectedOptions = commands.affectedOptions(user.id());
        int mediaCount = commands.mediaCount(user.id());
        commands.queueMediaCleanup(user.id());
        if (kakaoUserId != null && queueProviderUnlink) commands.queueKakaoUnlink(kakaoUserId);
        commands.deleteSupportData(user.id());
        if (recoveryCrypto.hasHmacSecret()) {
            String resetSubject = recoveryCrypto.digest("subject", "user:" + user.id());
            String resetLimit = recoveryCrypto.digest("limit", "request-subject\0" + resetSubject);
            commands.deleteResetLimit(resetLimit);
        }
        commands.detachOtherAuthorsReplies(user.id());
        commands.markPending(user.id());
        if (commands.deletePendingUser(user.id()) != 1) {
            throw new ApiException(HttpStatus.CONFLICT, "account-deletion", "Account deletion",
                    "계정 삭제를 완료하지 못했어요. 다시 시도해 주세요.", "ACCOUNT_DELETION_CONFLICT");
        }
        affectedPosts.forEach(commands::refreshPostCounts);
        affectedOptions.forEach(commands::refreshOptionCounts);
        return AccountDeletionReceipt.accepted(kakaoUserId != null || mediaCount > 0);
    }
}
