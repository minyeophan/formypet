package com.formypet.domain.auth.controller;

import com.formypet.domain.auth.service.RecoveryService;
import com.formypet.domain.auth.dto.request.ResetRequest;
import com.formypet.domain.auth.dto.request.ResetVerifyRequest;
import com.formypet.domain.auth.dto.request.ResetConfirmRequest;
import com.formypet.domain.auth.dto.response.ResetChallengeResponse;
import com.formypet.domain.auth.dto.response.ResetVerifiedResponse;

import com.formypet.common.response.ApiResponse;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/auth/password-reset")
@RequiredArgsConstructor
public class RecoveryController {
    private final RecoveryService service;
    @PostMapping("/request") public ApiResponse<ResetChallengeResponse> request(@Valid @RequestBody ResetRequest body,HttpServletRequest request){
        return ApiResponse.of(service.request(body.email(),request.getRemoteAddr()));
    }
    @PostMapping("/verify") public ApiResponse<ResetVerifiedResponse> verify(@Valid @RequestBody ResetVerifyRequest body,HttpServletRequest request){
        return ApiResponse.of(service.verify(body,request.getRemoteAddr()));
    }
    @PostMapping("/confirm") public ApiResponse<Void> confirm(@Valid @RequestBody ResetConfirmRequest body,HttpServletRequest request){
        service.confirm(body,request.getRemoteAddr());return ApiResponse.empty();
    }
}
