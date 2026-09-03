package com.formypet.common.exception;

import org.springframework.http.HttpStatus;

import java.net.URI;

public class ApiException extends RuntimeException {

    private final HttpStatus status;
    private final URI type;
    private final String title;
    private final String errorCode;

    public ApiException(HttpStatus status, String typeSlug, String title, String detail, String errorCode) {
        super(detail);
        this.status = status;
        this.type = URI.create("https://formypet.com/errors/" + typeSlug);
        this.title = title;
        this.errorCode = errorCode;
    }

    public HttpStatus status() {
        return status;
    }

    public URI type() {
        return type;
    }

    public String title() {
        return title;
    }

    public String detail() {
        return getMessage();
    }

    public String errorCode() {
        return errorCode;
    }
}
