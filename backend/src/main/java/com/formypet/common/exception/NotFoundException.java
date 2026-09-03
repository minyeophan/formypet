package com.formypet.common.exception;

import org.springframework.http.HttpStatus;

public class NotFoundException extends ApiException {

    public NotFoundException(String detail, String errorCode) {
        super(HttpStatus.NOT_FOUND, "not-found", "Not Found", detail, errorCode);
    }
}
