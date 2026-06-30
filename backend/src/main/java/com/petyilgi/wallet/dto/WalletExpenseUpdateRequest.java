package com.petyilgi.wallet.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.LocalDate;
import java.time.LocalTime;

public record WalletExpenseUpdateRequest(
        @NotNull LocalDate expenseDate,
        LocalTime expenseTime,
        @NotNull @Min(1) @Max(999_999_999) Long amount,
        String currency,
        @NotBlank String category,
        @Size(max = 100) String itemName,
        @Size(max = 500) String note
) {
}
