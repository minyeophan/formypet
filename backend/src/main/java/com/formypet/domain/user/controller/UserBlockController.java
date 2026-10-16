package com.formypet.domain.user.controller;

import com.formypet.domain.user.service.UserBlockService;
import com.formypet.domain.user.dto.response.BlockList;

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
    public ApiResponse<BlockList> list(@AuthenticationPrincipal(expression = "id") Long actorId) {
        return ApiResponse.of(service.list(actorId));
    }

    @PutMapping("/{userId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void block(@AuthenticationPrincipal(expression = "id") Long actorId, @PathVariable Long userId) {
        service.block(actorId, userId);
    }

    @DeleteMapping("/{userId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void unblock(@AuthenticationPrincipal(expression = "id") Long actorId, @PathVariable Long userId) {
        service.unblock(actorId, userId);
    }
}
