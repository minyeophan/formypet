package com.formypet.user;

import com.formypet.common.response.ApiResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/users/me/blocks")
@RequiredArgsConstructor
public class UserBlockController {
    private final UserBlockService service;

    @GetMapping
    public ApiResponse<UserBlockService.BlockList> list(@AuthenticationPrincipal String email) {
        return ApiResponse.of(service.list(email));
    }

    @PutMapping("/{userId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void block(@AuthenticationPrincipal String email, @PathVariable Long userId) {
        service.block(email, userId);
    }

    @DeleteMapping("/{userId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void unblock(@AuthenticationPrincipal String email, @PathVariable Long userId) {
        service.unblock(email, userId);
    }
}
