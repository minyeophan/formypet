package com.formypet.user;

import com.formypet.common.response.ApiResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequiredArgsConstructor
public class PublicAccountDeletionController {
    private final PublicAccountDeletionRequestService service;

    @PostMapping("/api/v1/public/account-deletion-requests")
    @ResponseStatus(HttpStatus.ACCEPTED)
    public ApiResponse<PublicAccountDeletionRequestService.Receipt> submit(
            @Valid @RequestBody PublicAccountDeletionRequest request) {
        return ApiResponse.of(service.submit(request));
    }
}
