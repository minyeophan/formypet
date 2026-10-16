package com.formypet.domain.user.dto.response;

public record AccountDeletionReceipt(String status, boolean externalCleanupPending) {
    public static AccountDeletionReceipt accepted(boolean pending) {
        return new AccountDeletionReceipt("ACCEPTED", pending);
    }
}
