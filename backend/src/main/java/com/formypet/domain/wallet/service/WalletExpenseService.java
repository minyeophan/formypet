package com.formypet.domain.wallet.service;

import com.formypet.domain.wallet.dto.request.*;
import com.formypet.domain.wallet.dto.response.*;
import java.time.LocalDate;

public interface WalletExpenseService {
    WalletExpenseResponse create(Long actorId, Long petId, WalletExpenseCreateRequest request);
    WalletExpenseListResponse list(Long actorId, Long petId, String cursor, Integer limit, LocalDate from, LocalDate to, String category);
    WalletExpenseSummaryResponse summary(Long actorId, Long petId, LocalDate from, LocalDate to, String category);
    WalletExpenseResponse get(Long actorId, Long petId, Long expenseId);
    WalletExpenseResponse update(Long actorId, Long petId, Long expenseId, WalletExpenseUpdateRequest request);
    void delete(Long actorId, Long petId, Long expenseId);
}
