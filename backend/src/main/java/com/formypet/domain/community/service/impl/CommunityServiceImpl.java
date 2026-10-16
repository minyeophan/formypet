package com.formypet.domain.community.service.impl;

import com.formypet.domain.community.service.*;
import com.formypet.domain.community.dto.*;
import com.formypet.domain.community.dto.request.*;
import com.formypet.domain.community.dto.response.*;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import java.util.List;

@Service
@RequiredArgsConstructor
public class CommunityServiceImpl implements CommunityService {
    private final PostService postService;
    private final CommentService commentService;
    private final ReactionService reactionService;
    private final ActivityService activityService;
    @Override
    public PostResponse create(Long actorId, PostCreateRequest request, List<MultipartFile> files){
        return postService.create(actorId, request, files);
    }

    @Override
    public PostFeedResponse feed(Long actorId, String keyword, String category, String sort, String cursor, int limit){
        return postService.feed(actorId, keyword, category, sort, cursor, limit);
    }

    @Override
    public PostResponse detail(Long actorId, Long postId){
        return postService.detail(actorId, postId);
    }

    @Override
    public PostResponse update(Long actorId, Long postId, PostUpdateRequest request){
        return postService.update(actorId, postId, request);
    }

    @Override
    public void delete(Long actorId, Long postId){
        postService.delete(actorId, postId);
    }

    @Override
    public PostCommentFeedResponse comments(Long actorId, Long postId, String cursor, int limit, int replyLimit){
        return commentService.comments(actorId, postId, cursor, limit, replyLimit);
    }

    @Override
    public PostCommentResponse commentThread(Long actorId, Long postId, Long commentId, int replyLimit){
        return commentService.commentThread(actorId, postId, commentId, replyLimit);
    }

    @Override
    public PostCommentFeedResponse replies(Long actorId, Long postId, Long commentId, String cursor, int limit){
        return commentService.replies(actorId, postId, commentId, cursor, limit);
    }

    @Override
    public PostCommentResponse createComment(Long actorId, Long postId, PostCommentCreateRequest request){
        return commentService.createComment(actorId, postId, request);
    }

    @Override
    public PostCommentResponse updateComment(Long actorId, Long postId, Long commentId,
                                             PostCommentUpdateRequest request){
        return commentService.updateComment(actorId, postId, commentId, request);
    }

    @Override
    public void deleteComment(Long actorId, Long postId, Long commentId){
        commentService.deleteComment(actorId, postId, commentId);
    }

    @Override
    public PostCommentReportResponse reportComment(Long actorId, Long postId, Long commentId,
                                                    PostCommentReportRequest request){
        return commentService.reportComment(actorId, postId, commentId, request);
    }

    @Override
    public PostLikeResponse toggleLike(Long actorId, Long postId){
        return reactionService.toggleLike(actorId, postId);
    }

    @Override
    public PostResponse vote(Long actorId, Long postId, Long optionId){
        return reactionService.vote(actorId, postId, optionId);
    }

    @Override
    public com.formypet.domain.community.dto.response.MyActivityResponse myActivities(
            Long actorId, String type, String cursor, int limit){
        return activityService.myActivities(actorId, type, cursor, limit);
    }
}
