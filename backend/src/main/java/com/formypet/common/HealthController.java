package com.formypet.common;

import com.formypet.common.response.ApiResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "Health", description = "서버 상태 확인")
@RestController
@RequestMapping("/api/v1")
public class HealthController {

    @Operation(summary = "Health Check",
               description = "Virtual Thread 동작 및 서버 상태 확인")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "서버 정상")
    @GetMapping("/health")
    public ApiResponse<String> health() {
        String threadInfo = Thread.currentThread().isVirtual()
                ? "Virtual Thread ✅" : "Platform Thread ⚠️";
        return ApiResponse.of(threadInfo);
    }
}
