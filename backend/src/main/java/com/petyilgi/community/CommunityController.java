package com.petyilgi.community;

import com.petyilgi.common.response.ApiResponse;
import com.petyilgi.community.dto.PostCreateRequest;
import com.petyilgi.community.dto.PostFeedResponse;
import com.petyilgi.community.dto.PostLikeResponse;
import com.petyilgi.community.dto.PostResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/posts")
@RequiredArgsConstructor
public class CommunityController {

    private final CommunityService communityService;

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<PostResponse> create(@AuthenticationPrincipal String email,
                                            @Valid @RequestBody PostCreateRequest request) {
        return ApiResponse.of(communityService.create(email, request));
    }

    @GetMapping
    public ApiResponse<PostFeedResponse> feed(@AuthenticationPrincipal String email,
                                              @RequestParam(required = false) Long cursor,
                                              @RequestParam(defaultValue = "20") int limit) {
        return ApiResponse.of(communityService.feed(email, cursor, limit));
    }

    @PostMapping("/{postId}/like")
    public ApiResponse<PostLikeResponse> toggleLike(@AuthenticationPrincipal String email,
                                                    @PathVariable Long postId) {
        return ApiResponse.of(communityService.toggleLike(email, postId));
    }
}
