package com.formypet.support;

import com.formypet.common.response.ApiResponse;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequiredArgsConstructor
public class SupportController {
    private final SupportService service;

    public record InquiryRequest(
            @NotBlank @Pattern(regexp = "ACCOUNT|RECORD_ROUTINE|COMMUNITY|BUG|OTHER") String type,
            @NotBlank @Email @Size(max = 254) @Pattern(regexp = "[^\\r\\n]+") String replyEmail,
            @NotBlank @Size(max = 100) @Pattern(regexp = "[^\\r\\n]+") String title,
            @NotBlank @Size(max = 3000) String body,
            @NotBlank @Pattern(regexp = "[A-Za-z0-9_-]{1,64}") String requestId) {}

    public record ReportRequest(
            @NotBlank @Pattern(regexp = "SPAM|ABUSE|INAPPROPRIATE|PRIVACY|OTHER") String reason,
            @Size(max = 500) String detail,
            @NotBlank @Pattern(regexp = "[A-Za-z0-9_-]{1,64}") String requestId) {}

    @PostMapping("/api/v1/inquiries")
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<SupportService.Receipt> inquiry(@AuthenticationPrincipal String email,
                                                       @Valid @RequestBody InquiryRequest request) {
        return ApiResponse.of(service.inquiry(email, request));
    }

    @PostMapping("/api/v1/posts/{postId}/reports")
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<SupportService.Receipt> report(@AuthenticationPrincipal String email,
            @PathVariable Long postId, @Valid @RequestBody ReportRequest request) {
        return ApiResponse.of(service.report(email, postId, request));
    }
}
