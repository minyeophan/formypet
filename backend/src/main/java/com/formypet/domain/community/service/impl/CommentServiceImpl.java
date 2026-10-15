package com.formypet.domain.community.service.impl;

import com.formypet.domain.community.repository.query.CommentProjectionRepository;
import com.formypet.domain.community.repository.query.CommentProjectionRepository.CommentSnapshot;

import com.formypet.auth.domain.User;
import com.formypet.domain.community.entity.*;
import com.formypet.domain.community.entity.PostComment;
import com.formypet.domain.community.repository.PostCommentRepository;
import com.formypet.domain.community.repository.jdbc.PostCounterRepository;
import com.formypet.domain.community.dto.request.PostCommentCreateRequest;
import com.formypet.domain.community.dto.response.PostCommentFeedResponse;
import com.formypet.domain.community.dto.response.PostCommentResponse;
import com.formypet.domain.community.dto.request.PostCommentUpdateRequest;
import com.formypet.domain.community.dto.request.PostCommentReportRequest;
import com.formypet.domain.community.dto.response.PostCommentReportResponse;
import com.formypet.domain.notification.service.NotificationService;
import com.formypet.domain.notification.entity.NotificationType;
import com.formypet.common.exception.ApiException;
import com.formypet.common.exception.ForbiddenException;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.time.Instant;
import com.formypet.common.time.UtcTime;
import java.util.*;

import com.formypet.domain.community.service.*;
import com.formypet.domain.community.repository.*;
import com.formypet.domain.community.repository.query.*;
import com.formypet.domain.community.repository.jdbc.*;

@Service
@RequiredArgsConstructor
public class CommentServiceImpl implements CommentService {

    private final CommunityAccess access;
    private final PostCommentReportRepository reports;
    private final PostCommentRepository commentRepository;
    private final PostCounterRepository counters;
    private final CommentProjectionRepository commentQueries;
    private final PostProjectionRepository postQueries;
    private final NotificationService notificationService;

    @Transactional(readOnly = true)
    public PostCommentFeedResponse comments(Long actorId, Long postId, String cursor, int limit, int replyLimit) {
        User user = access.findUser(actorId);
        access.ensurePostVisible(postId, user.getId());
        return commentQueries.comments(user.getId(), postId, cursor, limit, replyLimit);
    }

    @Transactional(readOnly = true)
    public PostCommentResponse commentThread(Long actorId, Long postId, Long commentId, int replyLimit) {
        User user = access.findUser(actorId);
        access.ensurePostVisible(postId, user.getId());
        return commentQueries.commentThread(user.getId(), postId, commentId, replyLimit);
    }

    @Transactional(readOnly = true)
    public PostCommentFeedResponse replies(Long actorId, Long postId, Long commentId, String cursor, int limit) {
        User user = access.findUser(actorId);
        access.ensurePostVisible(postId, user.getId());
        return commentQueries.replies(user.getId(), postId, commentId, cursor, limit);
    }

    @Transactional
    public PostCommentResponse createComment(Long actorId, Long postId, PostCommentCreateRequest request) {
        User user = access.findUser(actorId);
        access.ensurePostVisible(postId, user.getId());
        if (request == null) {
            throw new IllegalArgumentException("Comment content must be between 1 and 1000 characters.");
        }
        String content = PostComment.normalizeContent(request.content());
        Long parentCommentId = request.parentCommentId();
        if (parentCommentId != null) {
            CommentSnapshot parent = requireCommentAnyPost(parentCommentId);
            if (parent.deletedAt() != null) {
                throw commentNotFound();
            }
            if (!postId.equals(parent.postId())
                    || parent.parentCommentId() != null) {
                throw invalidCommentParent();
            }
        }
        PostComment comment = commentRepository.saveAndFlush(
                PostComment.create(postId, user.getId(), parentCommentId, content));
        counters.incrementComments(postId);
        Long commentId = comment.getId();
        Long recipient = parentCommentId == null
                ? postQueries.authorId(postId)
                : requireCommentAnyPost(parentCommentId).userId();
        notificationService.create(recipient, user.getId(), user.getNickname(),
                parentCommentId == null ? NotificationType.COMMENT : NotificationType.REPLY, postId, commentId);
        return commentQueries.findCommentResponse(commentId, commentsCount(postId));
    }

    @Transactional
    public PostCommentResponse updateComment(Long actorId, Long postId, Long commentId,
                                             PostCommentUpdateRequest request) {
        User user = access.findUser(actorId);
        access.ensurePostExists(postId);
        CommentSnapshot comment = requireActiveComment(postId, commentId);
        if (!user.getId().equals(comment.userId())) {
            throw new ForbiddenException(
                    "Forbidden comment.", "COMMENT_FORBIDDEN");
        }
        String content = request.content().trim();
        LocalDateTime updatedAt = UtcTime.toDatabase(Instant.now());
        int updated = commentRepository.updateActive(commentId, postId, content, updatedAt);
        if (updated != 1) {
            throw commentNotFound();
        }
        return commentQueries.findCommentResponse(commentId, commentsCount(postId));
    }

    @Transactional
    public void deleteComment(Long actorId, Long postId, Long commentId) {
        User user = access.findUser(actorId);
        access.ensurePostExists(postId);
        CommentSnapshot comment = requireActiveComment(postId, commentId);
        Long postAuthorId = postQueries.authorId(postId);
        Long commentAuthorId = comment.userId();
        if (!user.getId().equals(commentAuthorId) && !user.getId().equals(postAuthorId)) {
            throw new ForbiddenException(
                    "Forbidden comment.", "COMMENT_FORBIDDEN");
        }
        int updated = commentRepository.deleteActive(commentId, postId, UtcTime.toDatabase(Instant.now()));
        if (updated != 1) throw commentNotFound();
        counters.decrementComments(postId);
    }

    @Transactional
    public PostCommentReportResponse reportComment(Long actorId, Long postId, Long commentId,
                                                    PostCommentReportRequest request) {
        User reporter = access.findUser(actorId);
        access.ensurePostExists(postId);
        CommentSnapshot comment = requireActiveComment(postId, commentId);
        if (reporter.getId().equals(comment.userId())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "self-comment-report", "Invalid Comment Report",
                    "You cannot report your own comment.", "SELF_COMMENT_REPORT");
        }
        PostCommentReport report = PostCommentReport.create(commentId, reporter.getId(), request.reason().name(),
                request.detail(), comment.content());
        if (reports.existsByCommentIdAndReporterUserId(commentId, reporter.getId())) throw duplicateReport();
        try {
            reports.saveAndFlush(report);
        } catch (org.springframework.dao.DataIntegrityViolationException exception) {
            for (Throwable cause = exception; cause != null; cause = cause.getCause()) {
                if (cause instanceof java.sql.SQLException sql && sql.getErrorCode() == 1062) throw duplicateReport();
            }
            throw exception;
        }
        return new PostCommentReportResponse(report.getId(), commentId, request.reason(), report.getDetail(),
                UtcTime.fromDatabase(report.getCreatedAt()));
    }

    private CommentSnapshot requireActiveComment(Long postId, Long commentId) {
        CommentSnapshot row = requireCommentAnyPost(commentId);
        if (!postId.equals(row.postId()) || row.deletedAt() != null) {
            throw commentNotFound();
        }
        return row;
    }

    private CommentSnapshot requireCommentAnyPost(Long commentId) {
        return commentQueries.requireSnapshot(commentId);
    }

    private ApiException commentNotFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "comment-not-found", "Comment Not Found",
                "Comment not found.", "COMMENT_NOT_FOUND");
    }

    private ApiException invalidCommentParent() {
        return new ApiException(HttpStatus.BAD_REQUEST, "invalid-comment-parent", "Invalid Comment Parent",
                "The parent comment must be a root comment on the same post.", "INVALID_COMMENT_PARENT");
    }

    private int commentsCount(Long postId) {
        return postQueries.commentsCount(postId);
    }
    private ApiException duplicateReport() {
        return new ApiException(HttpStatus.CONFLICT, "duplicate-comment-report", "Duplicate Comment Report",
                "You have already reported this comment.", "DUPLICATE_COMMENT_REPORT");
    }
}
