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
import io.swagger.v3.oas.annotations.tags.Tag;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.Parameter;

@RestController
@RequestMapping("/api/v1/posts")
@RequiredArgsConstructor
@Tag(name = "Community", description = "커뮤니티 게시글·댓글 API")
@SecurityRequirement(name = "bearerAuth")
public class CommunityController {

    private final CommunityService communityService;
    private final ObjectMapper objectMapper;

    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @Operation(summary = "게시글 작성")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "201", description = "게시글 작성 성공")
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<PostResponse> create(@AuthenticationPrincipal String email,
                                            @RequestPart("payload") String payload,
                                            @RequestPart(value = "files", required = false) List<MultipartFile> files) {
        return ApiResponse.of(communityService.create(email, parsePayload(payload), files == null ? List.of() : files));
    }

    @GetMapping
    @Operation(summary = "게시글 피드 조회", description = "sort는 latest 또는 popular이며 limit은 1~50입니다.")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "피드 조회 성공")
    public ApiResponse<PostFeedResponse> feed(@AuthenticationPrincipal String email,
                                              @RequestParam(required = false) String keyword,
                                              @RequestParam(required = false) String category,
                                              @RequestParam(defaultValue = "latest") String sort,
                                              @Parameter(description = "다음 페이지 cursor", required = false) @RequestParam(required = false) String cursor,
                                              @Parameter(description = "페이지 크기 (1~50)", example = "10") @RequestParam(defaultValue = "10") int limit) {
        return ApiResponse.of(communityService.feed(email, keyword, category, sort, cursor, limit));
    }

    @GetMapping("/{postId}")
    @Operation(summary = "게시글 상세 조회")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "게시글 조회 성공")
    public ApiResponse<PostResponse> detail(@AuthenticationPrincipal String email, @PathVariable Long postId) {
        return ApiResponse.of(communityService.detail(email, postId));
    }

    @GetMapping("/{postId}/comments")
    @Operation(summary = "게시글 댓글 조회")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "댓글 조회 성공")
    public ApiResponse<PostCommentFeedResponse> comments(@AuthenticationPrincipal String email,
                                                          @PathVariable Long postId,
                                                          @Parameter(description = "다음 페이지 cursor", required = false) @RequestParam(required = false) String cursor,
                                                          @Parameter(description = "댓글 페이지 크기 (1~50)", example = "20") @RequestParam(defaultValue = "20") int limit,
                                                          @Parameter(description = "답글 페이지 크기 (1~50)", example = "20") @RequestParam(defaultValue = "20") int replyLimit) {
        return ApiResponse.of(communityService.comments(email, postId, cursor, limit, replyLimit));
    }

    @GetMapping("/{postId}/comments/{commentId}")
    @Operation(summary = "댓글 스레드 조회")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "스레드 조회 성공")
    public ApiResponse<PostCommentResponse> commentThread(@AuthenticationPrincipal String email,
                                                           @PathVariable Long postId,
                                                           @PathVariable Long commentId,
                                                           @RequestParam(defaultValue = "20") int replyLimit) {
        return ApiResponse.of(communityService.commentThread(email, postId, commentId, replyLimit));
    }

    @GetMapping("/{postId}/comments/{commentId}/replies")
    @Operation(summary = "댓글 답글 조회")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "답글 조회 성공")
    public ApiResponse<PostCommentFeedResponse> replies(@AuthenticationPrincipal String email,
                                                         @PathVariable Long postId,
                                                         @PathVariable Long commentId,
                                                         @Parameter(description = "다음 페이지 cursor", required = false) @RequestParam(required = false) String cursor,
                                                         @Parameter(description = "페이지 크기 (1~50)", example = "20") @RequestParam(defaultValue = "20") int limit) {
        return ApiResponse.of(communityService.replies(email, postId, commentId, cursor, limit));
    }

    @PostMapping("/{postId}/comments")
    @Operation(summary = "댓글 작성")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "201", description = "댓글 작성 성공")
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<PostCommentResponse> createComment(@AuthenticationPrincipal String email,
                                                          @PathVariable Long postId,
                                                          @RequestBody PostCommentCreateRequest request) {
        return ApiResponse.of(communityService.createComment(email, postId, request));
    }

    @PatchMapping("/{postId}/comments/{commentId}")
    @Operation(summary = "댓글 수정")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "댓글 수정 성공")
    public ApiResponse<PostCommentResponse> updateComment(@AuthenticationPrincipal String email,
                                                          @PathVariable Long postId,
                                                          @PathVariable Long commentId,
                                                          @Valid @RequestBody PostCommentUpdateRequest request) {
        return ApiResponse.of(communityService.updateComment(email, postId, commentId, request));
    }

    @DeleteMapping("/{postId}/comments/{commentId}")
    @Operation(summary = "댓글 삭제")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "204", description = "댓글 삭제 성공")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteComment(@AuthenticationPrincipal String email,
                              @PathVariable Long postId,
                              @PathVariable Long commentId) {
        communityService.deleteComment(email, postId, commentId);
    }

    @PostMapping("/{postId}/comments/{commentId}/reports")
    @Operation(summary = "댓글 신고")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "201", description = "신고 접수 성공")
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<PostCommentReportResponse> reportComment(@AuthenticationPrincipal String email,
                                                                 @PathVariable Long postId,
                                                                 @PathVariable Long commentId,
                                                                 @Valid @RequestBody PostCommentReportRequest request) {
        return ApiResponse.of(communityService.reportComment(email, postId, commentId, request));
    }

    @PostMapping("/{postId}/like")
    @Operation(summary = "게시글 좋아요 토글")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "좋아요 처리 성공")
    public ApiResponse<PostLikeResponse> toggleLike(@AuthenticationPrincipal String email,
                                                    @PathVariable Long postId) {
        return ApiResponse.of(communityService.toggleLike(email, postId));
    }

    @PostMapping("/{postId}/poll/options/{optionId}/vote")
    @Operation(summary = "게시글 투표")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "투표 성공")
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
