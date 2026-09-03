package com.formypet.auth.repository;

import com.formypet.auth.domain.OAuthAccount;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface OAuthAccountRepository extends JpaRepository<OAuthAccount, Long> {
    @EntityGraph(attributePaths = "user")
    Optional<OAuthAccount> findByProviderAndProviderUserId(String provider, String providerUserId);
}
