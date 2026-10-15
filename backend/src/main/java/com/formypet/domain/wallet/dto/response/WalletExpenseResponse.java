package com.formypet.domain.wallet.dto.response;

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
    public static String categoryLabel(String category) {
        return switch (category) {
            case "food" -> "\uC0AC\uB8CC";
            case "snack" -> "\uAC04\uC2DD";
            case "hospital" -> "\uBCD1\uC6D0";
            case "medicine" -> "\uC57D";
            case "grooming" -> "\uBBF8\uC6A9";
            case "supplies" -> "\uC6A9\uD488";
            case "etc" -> "\uAE30\uD0C0";
            default -> category;
        };
    }
}


