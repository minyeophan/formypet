package com.formypet.domain.wallet.dto.response;

public record WalletExpenseCategorySummary(
        String category,
        String categoryLabel,
        Long amount,
        Long count
) {
}
