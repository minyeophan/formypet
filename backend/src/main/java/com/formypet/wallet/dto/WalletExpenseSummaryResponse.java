package com.formypet.wallet.dto;

import java.time.LocalDate;
import java.util.List;

public record WalletExpenseSummaryResponse(
        Long totalAmount,
        Long count,
        String currency,
        LocalDate from,
        LocalDate to,
        List<WalletExpenseCategorySummary> categories
) {
}
