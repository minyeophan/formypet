package com.formypet.domain.auth.service;

import com.formypet.domain.auth.dto.request.ResetVerifyRequest;
import com.formypet.domain.auth.dto.request.ResetConfirmRequest;
import com.formypet.domain.auth.dto.response.ResetChallengeResponse;
import com.formypet.domain.auth.dto.response.ResetVerifiedResponse;

public interface RecoveryTransactions {
    ResetChallengeResponse request(String subject,Long identifiedUser);
    ResetVerifiedResponse verify(ResetVerifyRequest request);
    void confirm(ResetConfirmRequest request);
}
