package com.petyilgi.community;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.petyilgi.common.response.ApiResponse;
import com.petyilgi.community.dto.PostCreateRequest;
import com.petyilgi.community.dto.PostCommentCreateRequest;
import com.petyilgi.community.dto.PostCommentFeedResponse;
import com.petyilgi.community.dto.PostCommentResponse;
import com.petyilgi.community.dto.PostCommentReportRequest;
import com.petyilgi.community.dto.PostCommentReportResponse;
import com.petyilgi.community.dto.PostCommentUpdateRequest;
import com.petyilgi.community.dto.PostFeedResponse;
import com.petyilgi.community.dto.PostLikeResponse;
import com.petyilgi.community.dto.PostResponse;
import jakarta.validation.Valid;
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
                                              @RequestParam(required = false) String keyword,
                                              @RequestParam(required = false) String category,
                                              @RequestParam(defaultValue = "latest") String sort,
                                              @RequestParam(required = false) String cursor,
                                              @RequestParam(defaultValue = "10") int limit) {
        return ApiResponse.of(communityService.feed(email, keyword, category, sort, cursor, limit));
    }

    @GetMapping("/{postId}")
    public ApiResponse<PostResponse> detail(@AuthenticationPrincipal String email, @PathVariable Long postId) {
        return ApiResponse.of(communityService.detail(email, postId));
    }

    @GetMapping("/{postId}/comments")
    public ApiResponse<PostCommentFeedResponse> comments(@AuthenticationPrincipal String email,
                                                          @PathVariable Long postId,
                                                          @RequestParam(required = false) String cursor,
                                                          @RequestParam(defaultValue = "20") int limit,
                                                          @RequestParam(defaultValue = "20") int replyLimit) {
        return ApiResponse.of(communityService.comments(email, postId, cursor, limit, replyLimit));
    }

    @GetMapping("/{postId}/comments/{commentId}")
    public ApiResponse<PostCommentResponse> commentThread(@AuthenticationPrincipal String email,
                                                           @PathVariable Long postId,
                                                           @PathVariable Long commentId,
                                                           @RequestParam(defaultValue = "20") int replyLimit) {
        return ApiResponse.of(communityService.commentThread(email, postId, commentId, replyLimit));
    }

    @GetMapping("/{postId}/comments/{commentId}/replies")
    public ApiResponse<PostCommentFeedResponse> replies(@AuthenticationPrincipal String email,
                                                         @PathVariable Long postId,
                                                         @PathVariable Long commentId,
                                                         @RequestParam(required = false) String cursor,
                                                         @RequestParam(defaultValue = "20") int limit) {
        return ApiResponse.of(communityService.replies(email, postId, commentId, cursor, limit));
    }

    @PostMapping("/{postId}/comments")
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<PostCommentResponse> createComment(@AuthenticationPrincipal String email,
                                                          @PathVariable Long postId,
                                                          @RequestBody PostCommentCreateRequest request) {
        return ApiResponse.of(communityService.createComment(email, postId, request));
    }

    @PatchMapping("/{postId}/comments/{commentId}")
    public ApiResponse<PostCommentResponse> updateComment(@AuthenticationPrincipal String email,
                                                          @PathVariable Long postId,
                                                          @PathVariable Long commentId,
                                                          @Valid @RequestBody PostCommentUpdateRequest request) {
        return ApiResponse.of(communityService.updateComment(email, postId, commentId, request));
    }

    @DeleteMapping("/{postId}/comments/{commentId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteComment(@AuthenticationPrincipal String email,
                              @PathVariable Long postId,
                              @PathVariable Long commentId) {
        communityService.deleteComment(email, postId, commentId);
    }

    @PostMapping("/{postId}/comments/{commentId}/reports")
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<PostCommentReportResponse> reportComment(@AuthenticationPrincipal String email,
                                                                 @PathVariable Long postId,
                                                                 @PathVariable Long commentId,
                                                                 @Valid @RequestBody PostCommentReportRequest request) {
        return ApiResponse.of(communityService.reportComment(email, postId, commentId, request));
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
