package com.formypet.common.exception;

import com.formypet.auth.OAuthLoginConflictException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.validation.FieldError;
import org.springframework.web.HttpMediaTypeNotSupportedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.multipart.MaxUploadSizeExceededException;
import org.springframework.web.multipart.MultipartException;

import java.net.URI;
import java.util.Map;
import java.util.stream.Collectors;

@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final String ERROR_BASE = "https://formypet.com/errors/";

    @ExceptionHandler(ApiException.class)
    public ResponseEntity<ProblemDetail> handleApiException(ApiException ex) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(ex.status(), ex.detail());
        problem.setType(ex.type());
        problem.setTitle(ex.title());
        problem.setProperty("errorCode", ex.errorCode());
        var response = ResponseEntity.status(ex.status());
        if (ex.retryAfterSeconds() != null) {
            response.header("Retry-After", ex.retryAfterSeconds().toString());
        }
        return response.body(problem);
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ProblemDetail handleValidation(MethodArgumentNotValidException ex) {
        Map<String, String> fieldErrors = ex.getBindingResult()
                .getFieldErrors().stream()
                .collect(Collectors.toMap(
                        FieldError::getField,
                        fe -> fe.getDefaultMessage() != null ? fe.getDefaultMessage() : "invalid",
                        (left, right) -> left
                ));
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(
                HttpStatus.BAD_REQUEST, "Validation failed.");
        problem.setType(URI.create(ERROR_BASE + "validation-failed"));
        problem.setTitle("Validation Failed");
        problem.setProperty("errorCode", "VALIDATION_FAILED");
        problem.setProperty("fieldErrors", fieldErrors);
        return problem;
    }

    @ExceptionHandler({
            HttpMessageNotReadableException.class,
            MethodArgumentTypeMismatchException.class,
            MissingServletRequestParameterException.class,
            HttpMediaTypeNotSupportedException.class
    })
    public ProblemDetail handleInvalidInput(Exception ex) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(
                HttpStatus.BAD_REQUEST, "Invalid request.");
        problem.setType(URI.create(ERROR_BASE + "invalid-input"));
        problem.setTitle("Invalid Input");
        problem.setProperty("errorCode", "INVALID_INPUT");
        return problem;
    }

    @ExceptionHandler(MaxUploadSizeExceededException.class)
    public ProblemDetail handleUploadTooLarge(MaxUploadSizeExceededException ex) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(
                HttpStatus.PAYLOAD_TOO_LARGE, "Upload exceeds the configured limits.");
        problem.setType(URI.create(ERROR_BASE + "payload-too-large"));
        problem.setTitle("Payload Too Large");
        problem.setProperty("errorCode", "UPLOAD_TOO_LARGE");
        return problem;
    }

    @ExceptionHandler(MultipartException.class)
    public ProblemDetail handleInvalidMultipart(MultipartException ex) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(
                HttpStatus.BAD_REQUEST, "Invalid multipart request.");
        problem.setType(URI.create(ERROR_BASE + "invalid-input"));
        problem.setTitle("Invalid Input");
        problem.setProperty("errorCode", "INVALID_INPUT");
        return problem;
    }

    @ExceptionHandler(AccessDeniedException.class)
    public ProblemDetail handleAccessDenied(AccessDeniedException ex) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(
                HttpStatus.FORBIDDEN, ex.getMessage());
        problem.setType(URI.create(ERROR_BASE + "forbidden"));
        problem.setTitle("Forbidden");
        problem.setProperty("errorCode", "PET_FORBIDDEN");
        return problem;
    }

    @ExceptionHandler(BadCredentialsException.class)
    public ProblemDetail handleBadCredentials(BadCredentialsException ex) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(
                HttpStatus.UNAUTHORIZED, ex.getMessage());
        problem.setType(URI.create(ERROR_BASE + "unauthorized"));
        problem.setTitle("Unauthorized");
        problem.setProperty("errorCode", "UNAUTHORIZED");
        return problem;
    }

    @ExceptionHandler(IllegalArgumentException.class)
    public ProblemDetail handleIllegalArgument(IllegalArgumentException ex) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(
                HttpStatus.BAD_REQUEST, ex.getMessage());
        problem.setType(URI.create(ERROR_BASE + "invalid-input"));
        problem.setTitle("Invalid Input");
        problem.setProperty("errorCode", "INVALID_INPUT");
        return problem;
    }

    @ExceptionHandler(OAuthLoginConflictException.class)
    public ProblemDetail handleOAuthLoginConflict(OAuthLoginConflictException ex) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(
                HttpStatus.CONFLICT, ex.getMessage());
        problem.setType(URI.create(ERROR_BASE + "oauth-login-conflict"));
        problem.setTitle("OAuth Login Conflict");
        return problem;
    }

    @ExceptionHandler(Exception.class)
    public ProblemDetail handleGeneral(Exception ex) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(
                HttpStatus.INTERNAL_SERVER_ERROR, "Internal server error.");
        problem.setType(URI.create(ERROR_BASE + "internal"));
        problem.setTitle("Internal Server Error");
        return problem;
    }
}
