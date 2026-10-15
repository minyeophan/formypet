package com.formypet.domain.support.controller;

import com.formypet.domain.support.service.SupportService;
import com.formypet.domain.support.dto.request.InquiryRequest;
import com.formypet.domain.support.dto.request.ReportRequest;
import com.formypet.domain.support.dto.response.SupportReceipt;

import com.formypet.common.response.ApiResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequiredArgsConstructor
public class SupportController {
    private final SupportService service;

    @PostMapping("/api/v1/inquiries")
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<SupportReceipt> inquiry(@AuthenticationPrincipal(expression = "id") Long actorId,
                                                       @Valid @RequestBody InquiryRequest request) {
        return ApiResponse.of(service.inquiry(actorId, request));
    }

    @PostMapping("/api/v1/posts/{postId}/reports")
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<SupportReceipt> report(@AuthenticationPrincipal(expression = "id") Long actorId,
            @PathVariable Long postId, @Valid @RequestBody ReportRequest request) {
        return ApiResponse.of(service.report(actorId, postId, request));
    }
}
