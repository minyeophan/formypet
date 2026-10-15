package com.formypet.domain.policy.entity;

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
public class PolicyPublicationId implements Serializable {
    @Column(name = "document_type", length = 32, nullable = false, updatable = false)
    private String documentType;
    @Column(name = "document_version", length = 64, nullable = false, updatable = false)
    private String documentVersion;
}
