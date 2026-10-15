package com.formypet.domain.policy.repository;

import com.formypet.domain.policy.entity.PolicyRuntime;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;

public interface PolicyRuntimeRepository extends JpaRepository<PolicyRuntime, Integer> {
    @Query("select r.enforcementEnabled from PolicyRuntime r where r.id=1")
    boolean enforced();

    @Modifying(flushAutomatically = true)
    @Query("update PolicyRuntime r set r.enforcementEnabled=true where r.id=1")
    int enableEnforcement();
}
