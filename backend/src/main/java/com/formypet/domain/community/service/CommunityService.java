package com.formypet.domain.community.service;

import com.formypet.domain.community.dto.*;
import com.formypet.domain.community.dto.request.*;
import com.formypet.domain.community.dto.response.*;
import java.util.List;
import org.springframework.web.multipart.MultipartFile;

public interface CommunityService {
    com.formypet.domain.community.dto.response.MyActivityResponse myActivities(
            Long actorId, String type, String cursor, int limit);
    PostResponse create(Long actorId, PostCreateRequest request, List<MultipartFile> files);
    PostFeedResponse feed(Long actorId, String keyword, String category, String sort, String cursor, int limit);
    PostResponse detail(Long actorId, Long postId);
    PostResponse update(Long actorId, Long postId, PostUpdateRequest request);
    void delete(Long actorId, Long postId);
    PostCommentFeedResponse comments(Long actorId, Long postId, String cursor, int limit, int replyLimit);
    PostCommentResponse commentThread(Long actorId, Long postId, Long commentId, int replyLimit);
    PostCommentFeedResponse replies(Long actorId, Long postId, Long commentId, String cursor, int limit);
    PostCommentResponse createComment(Long actorId, Long postId, PostCommentCreateRequest request);
    PostCommentResponse updateComment(Long actorId, Long postId, Long commentId,
                                             PostCommentUpdateRequest request);
    void deleteComment(Long actorId, Long postId, Long commentId);
    PostCommentReportResponse reportComment(Long actorId, Long postId, Long commentId,
                                                    PostCommentReportRequest request);
    PostLikeResponse toggleLike(Long actorId, Long postId);
    PostResponse vote(Long actorId, Long postId, Long optionId);
}
