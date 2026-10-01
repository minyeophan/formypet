package com.formypet.auth;

public class OAuthLoginConflictException extends RuntimeException {
    public OAuthLoginConflictException(String message) {
        super(message);
    }
}
