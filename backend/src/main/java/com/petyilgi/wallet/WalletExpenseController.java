package com.petyilgi.wallet;

import com.petyilgi.common.response.ApiResponse;
import com.petyilgi.wallet.dto.WalletExpenseCreateRequest;
import com.petyilgi.wallet.dto.WalletExpenseListResponse;
import com.petyilgi.wallet.dto.WalletExpenseResponse;
import com.petyilgi.wallet.dto.WalletExpenseSummaryResponse;
import com.petyilgi.wallet.dto.WalletExpenseUpdateRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;

@RestController
@RequestMapping("/api/v1/pets/{petId}/wallet/expenses")
@RequiredArgsConstructor
public class WalletExpenseController {

    private final WalletExpenseService walletExpenseService;

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<WalletExpenseResponse> create(@AuthenticationPrincipal String email,
                                                     @PathVariable Long petId,
                                                     @Valid @RequestBody WalletExpenseCreateRequest request) {
        return ApiResponse.of(walletExpenseService.create(email, petId, request));
    }

    @GetMapping
    public ApiResponse<WalletExpenseListResponse> list(@AuthenticationPrincipal String email,
                                                       @PathVariable Long petId,
                                                       @RequestParam(required = false) String cursor,
                                                       @RequestParam(required = false) Integer limit,
                                                       @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
                                                       @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
                                                       @RequestParam(required = false) String category) {
        return ApiResponse.of(walletExpenseService.list(email, petId, cursor, limit, from, to, category));
    }

    @GetMapping("/summary")
    public ApiResponse<WalletExpenseSummaryResponse> summary(@AuthenticationPrincipal String email,
                                                             @PathVariable Long petId,
                                                             @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
                                                             @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
                                                             @RequestParam(required = false) String category) {
        return ApiResponse.of(walletExpenseService.summary(email, petId, from, to, category));
    }

    @GetMapping("/{expenseId}")
    public ApiResponse<WalletExpenseResponse> get(@AuthenticationPrincipal String email,
                                                  @PathVariable Long petId,
                                                  @PathVariable Long expenseId) {
        return ApiResponse.of(walletExpenseService.get(email, petId, expenseId));
    }

    @PutMapping("/{expenseId}")
    public ApiResponse<WalletExpenseResponse> update(@AuthenticationPrincipal String email,
                                                     @PathVariable Long petId,
                                                     @PathVariable Long expenseId,
                                                     @Valid @RequestBody WalletExpenseUpdateRequest request) {
        return ApiResponse.of(walletExpenseService.update(email, petId, expenseId, request));
    }

    @DeleteMapping("/{expenseId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@AuthenticationPrincipal String email,
                       @PathVariable Long petId,
                       @PathVariable Long expenseId) {
        walletExpenseService.delete(email, petId, expenseId);
    }
}
