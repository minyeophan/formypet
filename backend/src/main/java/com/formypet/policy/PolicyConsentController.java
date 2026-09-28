package com.formypet.policy;

import com.formypet.common.response.ApiResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import java.util.*;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/users/me")
public class PolicyConsentController {
    private final PolicyConsentService service;
    @GetMapping("/policy-status")
    public ApiResponse<PolicyConsentService.Status> status(@AuthenticationPrincipal(expression="id") Long id) {
        return ApiResponse.of(service.status(id));
    }
    @GetMapping("/policy-consents")
    public ApiResponse<List<Map<String,Object>>> history(@AuthenticationPrincipal(expression="id") Long id) {
        return ApiResponse.of(service.history(id));
    }
    @PostMapping("/policy-consents")
    public ApiResponse<PolicyConsentService.Status> accept(@AuthenticationPrincipal(expression="id") Long id,
                                                          @RequestBody PolicyAcceptance acceptance) {
        return ApiResponse.of(service.accept(id, acceptance));
    }
}
