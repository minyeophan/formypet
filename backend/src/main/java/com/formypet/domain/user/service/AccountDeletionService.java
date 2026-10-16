package com.formypet.domain.user.service;

import com.formypet.domain.user.dto.request.AccountDeletionRequest;
import com.formypet.domain.user.dto.response.AccountDeletionReceipt;

public interface AccountDeletionService {
    AccountDeletionReceipt delete(Long actorId, AccountDeletionRequest request);
}
