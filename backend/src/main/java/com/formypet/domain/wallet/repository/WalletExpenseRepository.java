package com.formypet.domain.wallet.repository;

import com.formypet.domain.wallet.entity.WalletExpense;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;

public interface WalletExpenseRepository extends JpaRepository<WalletExpense, Long> {
    Optional<WalletExpense> findByIdAndPetId(Long id, Long petId);
}
