package com.formypet.common.exception;

import org.springframework.http.HttpStatus;

public class InvalidInputException extends ApiException {

    public InvalidInputException(String detail, String errorCode) {
        super(HttpStatus.BAD_REQUEST, "invalid-input", "Invalid Input", detail, errorCode);
    }

    public static InvalidInputException invalidInput() {
        return new InvalidInputException("Invalid input.", "INVALID_INPUT");
    }
}
