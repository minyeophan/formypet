package com.formypet.community;

import com.formypet.common.response.ApiResponse;
import com.formypet.community.dto.MyActivityResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/me/community/activities")
public class MyActivityController {
    private final CommunityService service;

    @GetMapping
    public ApiResponse<MyActivityResponse> list(@AuthenticationPrincipal String email,
            @RequestParam String type, @RequestParam(required = false) String cursor,
            @RequestParam(defaultValue = "20") int limit) {
        return ApiResponse.of(service.myActivities(email, type, cursor, limit));
    }
}
