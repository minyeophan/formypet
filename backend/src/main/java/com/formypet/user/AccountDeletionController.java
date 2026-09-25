package com.formypet.user;

import com.formypet.common.response.ApiResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/users/me")
@RequiredArgsConstructor
public class AccountDeletionController {
    private final AccountDeletionService service;

    @DeleteMapping
    @ResponseStatus(HttpStatus.ACCEPTED)
    public ApiResponse<AccountDeletionReceipt> delete(
            @AuthenticationPrincipal String email,
            @Valid @RequestBody AccountDeletionRequest request) {
        return ApiResponse.of(service.delete(email, request));
    }
}
