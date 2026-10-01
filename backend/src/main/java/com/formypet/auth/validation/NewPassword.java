package com.formypet.auth.validation;

import jakarta.validation.Constraint;
import jakarta.validation.Payload;
import java.lang.annotation.*;

@Target({ElementType.FIELD, ElementType.PARAMETER, ElementType.RECORD_COMPONENT})
@Retention(RetentionPolicy.RUNTIME)
@Constraint(validatedBy = NewPasswordValidator.class)
public @interface NewPassword {
    String message() default "비밀번호는 8자 이상, UTF-8 72바이트 이하로 입력해 주세요.";
    Class<?>[] groups() default {};
    Class<? extends Payload>[] payload() default {};
}
