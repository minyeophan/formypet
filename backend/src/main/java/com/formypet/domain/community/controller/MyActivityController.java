package com.formypet.domain.community.controller;

import com.formypet.domain.community.service.CommunityService;

import com.formypet.global.response.ApiResponse;
import com.formypet.domain.community.dto.response.MyActivityResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/me/community/activities")
public class MyActivityController {
    private final CommunityService service;

    @GetMapping
    public ApiResponse<MyActivityResponse> list(@AuthenticationPrincipal(expression = "id") Long actorId,
            @RequestParam String type, @RequestParam(required = false) String cursor,
            @RequestParam(defaultValue = "20") int limit) {
        return ApiResponse.of(service.myActivities(actorId, type, cursor, limit));
    }
}
