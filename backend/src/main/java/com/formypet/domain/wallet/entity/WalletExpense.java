package com.formypet.domain.wallet.entity;

import com.formypet.common.exception.InvalidInputException;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.Set;

@Entity
@Table(name = "wallet_expenses")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class WalletExpense {
    private static final Set<String> CATEGORIES = Set.of(
            "food", "snack", "hospital", "medicine", "grooming", "supplies", "etc");
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(name = "user_id", nullable = false)
    private Long userId;
    @Column(name = "pet_id", nullable = false)
    private Long petId;
    @Column(name = "expense_date", nullable = false)
    private LocalDate expenseDate;
    @Column(name = "expense_time")
    private LocalTime expenseTime;
    @Column(nullable = false)
    private Long amount;
    @Column(nullable = false, length = 3)
    private String currency;
    @Column(nullable = false, length = 40)
    private String category;
    @Column(name = "item_name", length = 100)
    private String itemName;
    @Column(length = 500)
    private String note;

    // created_at/updated_at remain owned by the existing database defaults.
    public static WalletExpense create(Long userId, Long petId, LocalDate date, LocalTime time,
                                       Long amount, String currency, String category, String itemName, String note) {
        if (userId == null || petId == null) throw InvalidInputException.invalidInput();
        var expense = new WalletExpense();
        expense.userId = userId;
        expense.petId = petId;
        expense.update(date, time, amount, currency, category, itemName, note);
        return expense;
    }

    public void update(LocalDate date, LocalTime time, Long amount, String currency,
                       String category, String itemName, String note) {
        if (date == null || amount == null || amount < 1 || amount > 999_999_999L)
            throw InvalidInputException.invalidInput();
        String validCurrency = currency == null || currency.isBlank() ? "KRW" : currency.trim();
        if (!"KRW".equals(validCurrency)) throw InvalidInputException.invalidInput();
        String validCategory = normalizeCategory(category);
        if (itemName != null && itemName.length() > 100 || note != null && note.length() > 500)
            throw InvalidInputException.invalidInput();
        this.expenseDate = date;
        this.expenseTime = time;
        this.amount = amount;
        this.currency = validCurrency;
        this.category = validCategory;
        this.itemName = optionalText(itemName);
        this.note = optionalText(note);
    }

    public static String normalizeCategory(String category) {
        String value = category == null ? "" : category.trim();
        if (!CATEGORIES.contains(value)) throw InvalidInputException.invalidInput();
        return value;
    }

    private static String optionalText(String text) {
        return text == null || text.isBlank() ? null : text.trim();
    }
}
