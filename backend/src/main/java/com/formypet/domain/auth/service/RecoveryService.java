package com.formypet.domain.auth.service;

import com.formypet.domain.auth.dto.request.ResetVerifyRequest;
import com.formypet.domain.auth.dto.request.ResetConfirmRequest;
import com.formypet.domain.auth.dto.response.ResetChallengeResponse;
import com.formypet.domain.auth.dto.response.ResetVerifiedResponse;

public interface RecoveryService {
    ResetChallengeResponse request(String email,String ip);
    ResetVerifiedResponse verify(ResetVerifyRequest request,String ip);
    void confirm(ResetConfirmRequest request,String ip);
}
