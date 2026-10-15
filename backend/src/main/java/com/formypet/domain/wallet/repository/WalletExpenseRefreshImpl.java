package com.formypet.domain.wallet.repository;

import com.formypet.domain.wallet.entity.WalletExpense;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;

/** Read database-normalized values, including the existing TIME(0) precision. */
public class WalletExpenseRefreshImpl implements WalletExpenseRefresh {
    @PersistenceContext
    private EntityManager entityManager;

    @Override
    public void refreshStoredValues(WalletExpense expense) {
        entityManager.flush();
        entityManager.refresh(expense);
    }
}
