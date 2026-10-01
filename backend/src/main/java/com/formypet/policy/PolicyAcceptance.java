package com.formypet.policy;

import com.fasterxml.jackson.annotation.JsonAnySetter;

public record PolicyAcceptance(String termsVersion, boolean termsAccepted, boolean age14Confirmed,
                               String privacyNoticeVersion, boolean privacyNoticeAcknowledged) {
    @JsonAnySetter
    public void rejectUnknown(String name, Object value) {
        throw new IllegalArgumentException("Unknown policy acceptance field");
    }
}
