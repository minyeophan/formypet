package com.formypet.community;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.formypet.common.response.ApiResponse;
import com.formypet.community.dto.PostCreateRequest;
import com.formypet.community.dto.PostCommentCreateRequest;
import com.formypet.community.dto.PostCommentFeedResponse;
import com.formypet.community.dto.PostCommentResponse;
import com.formypet.community.dto.PostCommentReportRequest;
import com.formypet.community.dto.PostCommentReportResponse;
import com.formypet.community.dto.PostCommentUpdateRequest;
import com.formypet.community.dto.PostFeedResponse;
import com.formypet.community.dto.PostLikeResponse;
import com.formypet.community.dto.PostResponse;
import com.formypet.community.dto.PostUpdateRequest;
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
    public ApiResponse<PostResponse> create(@AuthenticationPrincipal(expression = "id") Long actorId,
                                            @RequestPart("payload") String payload,
                                            @RequestPart(value = "files", required = false) List<MultipartFile> files) {
        return ApiResponse.of(communityService.create(actorId, parsePayload(payload), files == null ? List.of() : files));
    }

    @GetMapping
    @Operation(summary = "게시글 피드 조회", description = "sort는 latest 또는 popular이며 limit은 1~50입니다.")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "피드 조회 성공")
    public ApiResponse<PostFeedResponse> feed(@AuthenticationPrincipal(expression = "id") Long actorId,
                                              @RequestParam(required = false) String keyword,
                                              @RequestParam(required = false) String category,
                                              @RequestParam(defaultValue = "latest") String sort,
                                              @Parameter(description = "다음 페이지 cursor", required = false) @RequestParam(required = false) String cursor,
                                              @Parameter(description = "페이지 크기 (1~50)", example = "10") @RequestParam(defaultValue = "10") int limit) {
        return ApiResponse.of(communityService.feed(actorId, keyword, category, sort, cursor, limit));
    }

    @GetMapping("/{postId}")
    @Operation(summary = "게시글 상세 조회")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "게시글 조회 성공")
    public ApiResponse<PostResponse> detail(@AuthenticationPrincipal(expression = "id") Long actorId, @PathVariable Long postId) {
        return ApiResponse.of(communityService.detail(actorId, postId));
    }

    @PutMapping("/{postId}")
    @Operation(summary = "게시글 수정")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "게시글 수정 성공")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "403", description = "작성자만 수정 가능")
    public ApiResponse<PostResponse> update(@AuthenticationPrincipal(expression = "id") Long actorId,
                                            @PathVariable Long postId,
                                            @Valid @RequestBody PostUpdateRequest request) {
        return ApiResponse.of(communityService.update(actorId, postId, request));
    }

    @DeleteMapping("/{postId}")
    @Operation(summary = "게시글 삭제")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "204", description = "게시글 삭제 성공")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "403", description = "작성자만 삭제 가능")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@AuthenticationPrincipal(expression = "id") Long actorId, @PathVariable Long postId) {
        communityService.delete(actorId, postId);
    }

    @GetMapping("/{postId}/comments")
    @Operation(summary = "게시글 댓글 조회")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "댓글 조회 성공")
    public ApiResponse<PostCommentFeedResponse> comments(@AuthenticationPrincipal(expression = "id") Long actorId,
                                                          @PathVariable Long postId,
                                                          @Parameter(description = "다음 페이지 cursor", required = false) @RequestParam(required = false) String cursor,
                                                          @Parameter(description = "댓글 페이지 크기 (1~50)", example = "20") @RequestParam(defaultValue = "20") int limit,
                                                          @Parameter(description = "답글 페이지 크기 (1~50)", example = "20") @RequestParam(defaultValue = "20") int replyLimit) {
        return ApiResponse.of(communityService.comments(actorId, postId, cursor, limit, replyLimit));
    }

    @GetMapping("/{postId}/comments/{commentId}")
    @Operation(summary = "댓글 스레드 조회")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "스레드 조회 성공")
    public ApiResponse<PostCommentResponse> commentThread(@AuthenticationPrincipal(expression = "id") Long actorId,
                                                           @PathVariable Long postId,
                                                           @PathVariable Long commentId,
                                                           @RequestParam(defaultValue = "20") int replyLimit) {
        return ApiResponse.of(communityService.commentThread(actorId, postId, commentId, replyLimit));
    }

    @GetMapping("/{postId}/comments/{commentId}/replies")
    @Operation(summary = "댓글 답글 조회")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "답글 조회 성공")
    public ApiResponse<PostCommentFeedResponse> replies(@AuthenticationPrincipal(expression = "id") Long actorId,
                                                         @PathVariable Long postId,
                                                         @PathVariable Long commentId,
                                                         @Parameter(description = "다음 페이지 cursor", required = false) @RequestParam(required = false) String cursor,
                                                         @Parameter(description = "페이지 크기 (1~50)", example = "20") @RequestParam(defaultValue = "20") int limit) {
        return ApiResponse.of(communityService.replies(actorId, postId, commentId, cursor, limit));
    }

    @PostMapping("/{postId}/comments")
    @Operation(summary = "댓글 작성")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "201", description = "댓글 작성 성공")
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<PostCommentResponse> createComment(@AuthenticationPrincipal(expression = "id") Long actorId,
                                                          @PathVariable Long postId,
                                                          @RequestBody PostCommentCreateRequest request) {
        return ApiResponse.of(communityService.createComment(actorId, postId, request));
    }

    @PatchMapping("/{postId}/comments/{commentId}")
    @Operation(summary = "댓글 수정")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "댓글 수정 성공")
    public ApiResponse<PostCommentResponse> updateComment(@AuthenticationPrincipal(expression = "id") Long actorId,
                                                          @PathVariable Long postId,
                                                          @PathVariable Long commentId,
                                                          @Valid @RequestBody PostCommentUpdateRequest request) {
        return ApiResponse.of(communityService.updateComment(actorId, postId, commentId, request));
    }

    @DeleteMapping("/{postId}/comments/{commentId}")
    @Operation(summary = "댓글 삭제")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "204", description = "댓글 삭제 성공")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteComment(@AuthenticationPrincipal(expression = "id") Long actorId,
                              @PathVariable Long postId,
                              @PathVariable Long commentId) {
        communityService.deleteComment(actorId, postId, commentId);
    }

    @PostMapping("/{postId}/comments/{commentId}/reports")
    @Operation(summary = "댓글 신고")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "201", description = "신고 접수 성공")
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<PostCommentReportResponse> reportComment(@AuthenticationPrincipal(expression = "id") Long actorId,
                                                                 @PathVariable Long postId,
                                                                 @PathVariable Long commentId,
                                                                 @Valid @RequestBody PostCommentReportRequest request) {
        return ApiResponse.of(communityService.reportComment(actorId, postId, commentId, request));
    }

    @PostMapping("/{postId}/like")
    @Operation(summary = "게시글 좋아요 토글")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "좋아요 처리 성공")
    public ApiResponse<PostLikeResponse> toggleLike(@AuthenticationPrincipal(expression = "id") Long actorId,
                                                    @PathVariable Long postId) {
        return ApiResponse.of(communityService.toggleLike(actorId, postId));
    }

    @PostMapping("/{postId}/poll/options/{optionId}/vote")
    @Operation(summary = "게시글 투표")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "투표 성공")
    public ApiResponse<PostResponse> vote(@AuthenticationPrincipal(expression = "id") Long actorId,
                                          @PathVariable Long postId,
                                          @PathVariable Long optionId) {
        return ApiResponse.of(communityService.vote(actorId, postId, optionId));
    }

    private PostCreateRequest parsePayload(String payload) {
        try {
            return objectMapper.readValue(payload, PostCreateRequest.class);
        } catch (JsonProcessingException e) {
            throw new IllegalArgumentException("Invalid post payload.");
        }
    }
}
