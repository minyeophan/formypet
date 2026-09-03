package com.formypet.wallet.dto;

public record WalletExpenseCategorySummary(
        String category,
        String categoryLabel,
        Long amount,
        Long count
) {
}
