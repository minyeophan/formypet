package com.petyilgi.wallet.dto;

public record WalletExpenseCategorySummary(
        String category,
        String categoryLabel,
        Long amount,
        Long count
) {
}
