package com.formypet.domain.wallet.entity;

import com.formypet.common.exception.InvalidInputException;
import org.junit.jupiter.api.Test;
import java.time.LocalDate;
import static org.assertj.core.api.Assertions.*;

class WalletExpenseTest {
    private WalletExpense create(Long amount, String currency, String category) {
        return WalletExpense.create(1L, 2L, LocalDate.of(2026, 10, 15), null,
                amount, currency, category, "  food  ", "   ");
    }

    @Test void preservesLegacyTrimSemantics() {
        var expense = WalletExpense.create(1L, 2L, LocalDate.of(2026, 10, 15), null,
                1000L, "KRW", "food", "\u2003", "\u0000");
        assertThat(expense.getItemName()).isEqualTo("\u2003");
        assertThat(expense.getNote()).isNull();
    }
    @Test void normalizesCurrencyCategoryAndOptionalText() {
        var expense = create(1000L, null, " food ");
        assertThat(expense.getCurrency()).isEqualTo("KRW");
        assertThat(expense.getCategory()).isEqualTo("food");
        assertThat(expense.getItemName()).isEqualTo("food");
        assertThat(expense.getNote()).isNull();
    }

    @Test void rejectsInvalidAmountsCurrenciesAndCategories() {
        for (Long amount : new Long[]{null, 0L, -1L, 1000000000L}) {
            assertThatThrownBy(() -> create(amount, "KRW", "food"))
                    .isInstanceOf(InvalidInputException.class);
        }
        assertThatThrownBy(() -> create(1L, "USD", "food"))
                .isInstanceOf(InvalidInputException.class);
        assertThatThrownBy(() -> create(1L, "KRW", "unknown"))
                .isInstanceOf(InvalidInputException.class);
        assertThat(create(999999999L, "KRW", "etc").getAmount()).isEqualTo(999999999L);
    }

    @Test void updateClearsOptionalFieldsAndKeepsOwnership() {
        var expense = create(1000L, "KRW", "food");
        expense.update(LocalDate.of(2026, 10, 16), null, 2000L, "KRW", "hospital", null, null);
        assertThat(expense.getUserId()).isEqualTo(1L);
        assertThat(expense.getPetId()).isEqualTo(2L);
        assertThat(expense.getAmount()).isEqualTo(2000L);
        assertThat(expense.getCategory()).isEqualTo("hospital");
        assertThat(expense.getItemName()).isNull();
        assertThat(expense.getNote()).isNull();
    }
}
