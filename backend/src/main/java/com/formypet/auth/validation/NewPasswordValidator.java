package com.formypet.auth.validation;

import jakarta.validation.ConstraintValidator;
import jakarta.validation.ConstraintValidatorContext;
import java.nio.charset.StandardCharsets;

public class NewPasswordValidator implements ConstraintValidator<NewPassword, String> {
    public boolean isValid(String value, ConstraintValidatorContext context) {
        return value != null && !value.isBlank()
                && value.codePointCount(0, value.length()) >= 8
                && value.getBytes(StandardCharsets.UTF_8).length <= 72;
    }
}
