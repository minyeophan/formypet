package com.formypet.domain.wallet.service.impl;

import com.formypet.global.exception.NotFoundException;
import com.formypet.global.exception.InvalidInputException;
import com.formypet.global.exception.ForbiddenException;
import com.formypet.domain.wallet.dto.request.*;
import com.formypet.domain.wallet.dto.response.*;
import com.formypet.domain.wallet.entity.WalletExpense;
import com.formypet.domain.wallet.repository.WalletExpenseRepository;
import com.formypet.domain.wallet.repository.query.WalletExpenseQueryRepository;
import com.formypet.domain.wallet.repository.query.WalletPetAccessRepository;
import com.formypet.domain.wallet.service.WalletExpenseService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.time.LocalDate;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class WalletExpenseServiceImpl implements WalletExpenseService {
    private final WalletExpenseRepository expenses;
    private final WalletExpenseQueryRepository queries;
    private final WalletPetAccessRepository access;

    @Override @Transactional
    public WalletExpenseResponse create(Long actorId, Long petId, WalletExpenseCreateRequest request) {
        var pet = findVisibleOwnedPet(actorId, petId);
        var expense = WalletExpense.create(pet.userId(), pet.id(), request.expenseDate(), request.expenseTime(),
                request.amount(), request.currency(), request.category(), request.itemName(), request.note());
        expenses.save(expense);
        expenses.refreshStoredValues(expense);
        return response(expense);
    }

    @Override
    public WalletExpenseListResponse list(Long actorId, Long petId, String cursor, Integer limit,
                                         LocalDate from, LocalDate to, String category) {
        findVisibleOwnedPet(actorId, petId);
        return queries.list(petId, cursor, limit, from, to, category);
    }

    @Override
    public WalletExpenseSummaryResponse summary(Long actorId, Long petId, LocalDate from, LocalDate to, String category) {
        findVisibleOwnedPet(actorId, petId);
        return queries.summary(petId, from, to, category);
    }

    @Override
    public WalletExpenseResponse get(Long actorId, Long petId, Long expenseId) {
        findVisibleOwnedPet(actorId, petId);
        return response(requireExpense(petId, expenseId));
    }

    @Override @Transactional
    public WalletExpenseResponse update(Long actorId, Long petId, Long expenseId, WalletExpenseUpdateRequest request) {
        findVisibleOwnedPet(actorId, petId);
        var expense = requireExpense(petId, expenseId);
        expense.update(request.expenseDate(), request.expenseTime(), request.amount(), request.currency(),
                request.category(), request.itemName(), request.note());
        expenses.refreshStoredValues(expense);
        return response(expense);
    }

    @Override @Transactional
    public void delete(Long actorId, Long petId, Long expenseId) {
        findVisibleOwnedPet(actorId, petId);
        expenses.delete(requireExpense(petId, expenseId));
        expenses.flush();
    }

    private WalletPetAccessRepository.PetRow findVisibleOwnedPet(Long actorId, Long petId) {
        if (!access.userExists(actorId)) {
            throw new InvalidInputException("User not found.", "INVALID_INPUT");
        }
        var pet = access.findPet(petId)
                .orElseThrow(() -> new NotFoundException("Pet not found.", "PET_NOT_FOUND"));
        if (!pet.userId().equals(actorId)) {
            throw new ForbiddenException("Forbidden pet.", "PET_FORBIDDEN");
        }
        if (pet.deleted()) {
            throw new NotFoundException("Pet not found or deleted.", "PET_NOT_FOUND_OR_DELETED");
        }
        return pet;
    }
    private WalletExpense requireExpense(Long petId, Long expenseId) {
        return expenses.findByIdAndPetId(expenseId, petId)
                .orElseThrow(() -> new NotFoundException("Wallet expense not found.", "WALLET_EXPENSE_NOT_FOUND"));
    }

    private WalletExpenseResponse response(WalletExpense expense) {
        return new WalletExpenseResponse(expense.getId(), expense.getPetId(), expense.getExpenseDate(),
                expense.getExpenseTime(), expense.getAmount(), expense.getCurrency(), expense.getCategory(),
                WalletExpenseResponse.categoryLabel(expense.getCategory()), expense.getItemName(), expense.getNote());
    }
}
