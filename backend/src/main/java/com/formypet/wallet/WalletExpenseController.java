package com.formypet.wallet;

import com.formypet.common.response.ApiResponse;
import com.formypet.wallet.dto.WalletExpenseCreateRequest;
import com.formypet.wallet.dto.WalletExpenseListResponse;
import com.formypet.wallet.dto.WalletExpenseResponse;
import com.formypet.wallet.dto.WalletExpenseSummaryResponse;
import com.formypet.wallet.dto.WalletExpenseUpdateRequest;
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
import io.swagger.v3.oas.annotations.tags.Tag;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.Parameter;

@RestController
@RequestMapping("/api/v1/pets/{petId}/wallet/expenses")
@RequiredArgsConstructor
@Tag(name = "Wallet Expenses", description = "지출 내역 및 요약 API")
@SecurityRequirement(name = "bearerAuth")
public class WalletExpenseController {

    private final WalletExpenseService walletExpenseService;

    @PostMapping
    @Operation(summary = "지출 내역 생성")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "201", description = "지출 생성 성공")
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<WalletExpenseResponse> create(@AuthenticationPrincipal String email,
                                                     @PathVariable Long petId,
                                                     @Valid @RequestBody WalletExpenseCreateRequest request) {
        return ApiResponse.of(walletExpenseService.create(email, petId, request));
    }

    @GetMapping
    @Operation(summary = "지출 내역 목록 조회")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "지출 목록 조회 성공")
    public ApiResponse<WalletExpenseListResponse> list(@AuthenticationPrincipal String email,
                                                       @PathVariable Long petId,
                                                       @Parameter(description = "다음 페이지 cursor", required = false) @RequestParam(required = false) String cursor,
                                                       @Parameter(description = "페이지 크기 (1~100)", required = false, example = "20") @RequestParam(required = false) Integer limit,
                                                       @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
                                                       @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
                                                       @RequestParam(required = false) String category) {
        return ApiResponse.of(walletExpenseService.list(email, petId, cursor, limit, from, to, category));
    }

    @GetMapping("/summary")
    @Operation(summary = "지출 요약 조회")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "지출 요약 조회 성공")
    public ApiResponse<WalletExpenseSummaryResponse> summary(@AuthenticationPrincipal String email,
                                                             @PathVariable Long petId,
                                                             @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
                                                             @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
                                                             @RequestParam(required = false) String category) {
        return ApiResponse.of(walletExpenseService.summary(email, petId, from, to, category));
    }

    @GetMapping("/{expenseId}")
    @Operation(summary = "지출 상세 조회")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "지출 조회 성공")
    public ApiResponse<WalletExpenseResponse> get(@AuthenticationPrincipal String email,
                                                  @PathVariable Long petId,
                                                  @PathVariable Long expenseId) {
        return ApiResponse.of(walletExpenseService.get(email, petId, expenseId));
    }

    @PutMapping("/{expenseId}")
    @Operation(summary = "지출 내역 수정")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "지출 수정 성공")
    public ApiResponse<WalletExpenseResponse> update(@AuthenticationPrincipal String email,
                                                     @PathVariable Long petId,
                                                     @PathVariable Long expenseId,
                                                     @Valid @RequestBody WalletExpenseUpdateRequest request) {
        return ApiResponse.of(walletExpenseService.update(email, petId, expenseId, request));
    }

    @DeleteMapping("/{expenseId}")
    @Operation(summary = "지출 내역 삭제")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "204", description = "지출 삭제 성공")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@AuthenticationPrincipal String email,
                       @PathVariable Long petId,
                       @PathVariable Long expenseId) {
        walletExpenseService.delete(email, petId, expenseId);
    }
}
