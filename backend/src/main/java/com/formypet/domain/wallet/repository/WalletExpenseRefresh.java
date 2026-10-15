package com.formypet.domain.wallet.repository;

import com.formypet.domain.wallet.entity.WalletExpense;

public interface WalletExpenseRefresh {
    void refreshStoredValues(WalletExpense expense);
}
