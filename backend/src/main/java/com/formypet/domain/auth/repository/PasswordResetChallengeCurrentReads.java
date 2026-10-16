package com.formypet.domain.auth.repository;

import com.formypet.domain.auth.entity.PasswordResetChallenge;
import java.util.Optional;

public interface PasswordResetChallengeCurrentReads {
    record ChallengeOwner(Long userId) {}
    Optional<ChallengeOwner> findOwnerById(String id);
    Optional<ChallengeOwner> findOwnerByResetHash(String hash);
    Optional<PasswordResetChallenge> findCurrentById(String id);
    Optional<PasswordResetChallenge> findCurrentByResetHash(String hash);
    void refreshCurrent(PasswordResetChallenge challenge);
}
