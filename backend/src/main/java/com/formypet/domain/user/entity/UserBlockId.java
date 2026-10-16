package com.formypet.domain.user.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;
import java.io.Serializable;
import lombok.AccessLevel;
import lombok.AllArgsConstructor;
import lombok.EqualsAndHashCode;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Embeddable
@Getter
@EqualsAndHashCode
@AllArgsConstructor
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class UserBlockId implements Serializable {
    @Column(name = "blocker_user_id", nullable = false)
    private Long blockerUserId;
    @Column(name = "blocked_user_id", nullable = false)
    private Long blockedUserId;
}
