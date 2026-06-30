package com.petyilgi.wallet.dto;

import java.time.LocalDate;
import java.time.LocalTime;

public record WalletExpenseResponse(
        Long id,
        Long petId,
        LocalDate expenseDate,
        LocalTime expenseTime,
        Long amount,
        String currency,
        String category,
        String categoryLabel,
        String itemName,
        String note
) {
}
