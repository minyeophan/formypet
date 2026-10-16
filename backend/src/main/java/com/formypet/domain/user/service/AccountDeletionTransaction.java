package com.formypet.domain.user.service;

import com.formypet.domain.user.dto.response.AccountDeletionReceipt;

public interface AccountDeletionTransaction {
    AccountDeletionReceipt delete(Long actorId, String password, String kakaoUserId);
    void deleteAfterKakaoUnlink(String providerUserId);
}
