package com.formypet.domain.auth.exception;

public class OAuthLoginConflictException extends RuntimeException {
    public OAuthLoginConflictException(String message) {
        super(message);
    }
}
