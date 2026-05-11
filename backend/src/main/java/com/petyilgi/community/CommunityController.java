package com.petyilgi.community;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.petyilgi.common.response.ApiResponse;
import com.petyilgi.community.dto.PostCreateRequest;
import com.petyilgi.community.dto.PostFeedResponse;
import com.petyilgi.community.dto.PostLikeResponse;
import com.petyilgi.community.dto.PostResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;

@RestController
@RequestMapping("/api/v1/posts")
@RequiredArgsConstructor
public class CommunityController {

    private final CommunityService communityService;
    private final ObjectMapper objectMapper;

    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<PostResponse> create(@AuthenticationPrincipal String email,
                                            @RequestPart("payload") String payload,
                                            @RequestPart(value = "files", required = false) List<MultipartFile> files) {
        return ApiResponse.of(communityService.create(email, parsePayload(payload), files == null ? List.of() : files));
    }

    @GetMapping
    public ApiResponse<PostFeedResponse> feed(@AuthenticationPrincipal String email,
                                              @RequestParam(required = false) String category,
                                              @RequestParam(defaultValue = "latest") String sort,
                                              @RequestParam(required = false) String cursor,
                                              @RequestParam(defaultValue = "10") int limit) {
        return ApiResponse.of(communityService.feed(email, category, sort, cursor, limit));
    }

    @PostMapping("/{postId}/like")
    public ApiResponse<PostLikeResponse> toggleLike(@AuthenticationPrincipal String email,
                                                    @PathVariable Long postId) {
        return ApiResponse.of(communityService.toggleLike(email, postId));
    }

    @PostMapping("/{postId}/poll/options/{optionId}/vote")
    public ApiResponse<PostResponse> vote(@AuthenticationPrincipal String email,
                                          @PathVariable Long postId,
                                          @PathVariable Long optionId) {
        return ApiResponse.of(communityService.vote(email, postId, optionId));
    }

    private PostCreateRequest parsePayload(String payload) {
        try {
            return objectMapper.readValue(payload, PostCreateRequest.class);
        } catch (JsonProcessingException e) {
            throw new IllegalArgumentException("Invalid post payload.");
        }
    }
}
