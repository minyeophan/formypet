package com.petyilgi.common.exception;

import org.springframework.http.HttpStatus;

public class ForbiddenException extends ApiException {

    public ForbiddenException(String detail, String errorCode) {
        super(HttpStatus.FORBIDDEN, "forbidden", "Forbidden", detail, errorCode);
    }
}
