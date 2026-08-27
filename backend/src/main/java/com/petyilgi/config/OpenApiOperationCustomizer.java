package com.petyilgi.config;

import io.swagger.v3.oas.models.Operation;
import io.swagger.v3.oas.models.responses.ApiResponse;
import org.springdoc.core.customizers.OperationCustomizer;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.method.HandlerMethod;

@Component
@Order
public class OpenApiOperationCustomizer implements OperationCustomizer {
    @Override
    public Operation customize(Operation operation, HandlerMethod handlerMethod) {
        operation.getResponses().addApiResponse("400", response("잘못된 요청"));
        operation.getResponses().addApiResponse("401", response("인증 필요"));
        operation.getResponses().addApiResponse("403", response("접근 권한 없음"));
        operation.getResponses().addApiResponse("404", response("리소스를 찾을 수 없음"));
        operation.getResponses().addApiResponse("409", response("충돌"));
        return operation;
    }

    private ApiResponse response(String description) {
        return new ApiResponse().description(description);
    }
}
