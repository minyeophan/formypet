package com.formypet.domain.auth.exception;

public final class RecoveryErrors {
    private RecoveryErrors() {}
    public static com.formypet.global.exception.ApiException error(int status, String code, String detail) {
        return new com.formypet.global.exception.ApiException(org.springframework.http.HttpStatus.valueOf(status), "password-reset", "Password recovery", detail, code);
    }
}
