package com.formypet.domain.policy.entity;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Entity
@Table(name = "policy_runtime")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class PolicyRuntime {
    @Id private Integer id;
    @Column(name = "enforcement_enabled", nullable = false)
    private boolean enforcementEnabled;

    /** A release may enable enforcement, but an older release cannot turn it off. */
    public void enableEnforcement() { enforcementEnabled = true; }
}
