package com.formypet.domain.community.service;

import com.formypet.domain.community.dto.*;
import com.formypet.domain.community.dto.request.*;
import com.formypet.domain.community.dto.response.*;
import org.springframework.web.multipart.MultipartFile;
import java.util.List;

public interface CommentService {
    public PostCommentFeedResponse comments(Long actorId, Long postId, String cursor, int limit, int replyLimit);
    public PostCommentResponse commentThread(Long actorId, Long postId, Long commentId, int replyLimit);
    public PostCommentFeedResponse replies(Long actorId, Long postId, Long commentId, String cursor, int limit);
    public PostCommentResponse createComment(Long actorId, Long postId, PostCommentCreateRequest request);
    public PostCommentResponse updateComment(Long actorId, Long postId, Long commentId,
                                             PostCommentUpdateRequest request);
    public void deleteComment(Long actorId, Long postId, Long commentId);
    public PostCommentReportResponse reportComment(Long actorId, Long postId, Long commentId,
                                                    PostCommentReportRequest request);
}
