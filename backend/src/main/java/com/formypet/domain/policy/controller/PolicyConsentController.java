package com.formypet.domain.policy.controller;
import com.formypet.domain.policy.dto.response.PolicyConsentStatusResponse;
import com.formypet.domain.policy.service.PolicyConsentService;
import com.formypet.domain.policy.dto.request.PolicyAcceptance;

import com.formypet.global.response.ApiResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import java.util.*;
import com.formypet.domain.policy.dto.response.PolicyConsentHistoryResponse;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/users/me")
public class PolicyConsentController {
    private final PolicyConsentService service;
    @GetMapping("/policy-status")
    public ApiResponse<PolicyConsentStatusResponse> status(@AuthenticationPrincipal(expression="id") Long id) {
        return ApiResponse.of(service.status(id));
    }
    @GetMapping("/policy-consents")
    public ApiResponse<List<PolicyConsentHistoryResponse>> history(@AuthenticationPrincipal(expression="id") Long id) {
        return ApiResponse.of(service.history(id));
    }
    @PostMapping("/policy-consents")
    public ApiResponse<PolicyConsentStatusResponse> accept(@AuthenticationPrincipal(expression="id") Long id,
                                                          @RequestBody PolicyAcceptance acceptance) {
        return ApiResponse.of(service.accept(id, acceptance));
    }
}
