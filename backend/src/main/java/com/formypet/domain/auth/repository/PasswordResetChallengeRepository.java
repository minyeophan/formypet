package com.formypet.domain.auth.repository;

import com.formypet.domain.auth.entity.PasswordResetChallenge;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PasswordResetChallengeRepository
        extends JpaRepository<PasswordResetChallenge, String>, PasswordResetChallengeCurrentReads {
}
