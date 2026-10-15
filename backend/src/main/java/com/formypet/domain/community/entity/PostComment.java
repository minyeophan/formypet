package com.formypet.domain.community.entity;

import com.formypet.common.time.UtcTime;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.JdbcType;
import org.hibernate.type.descriptor.jdbc.LocalDateTimeJdbcType;
import java.time.Instant;
import java.time.LocalDateTime;
import java.util.Objects;

@Entity
@Table(name = "post_comments")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class PostComment {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(name = "post_id", nullable = false, updatable = false)
    private Long postId;
    @Column(name = "user_id", nullable = false, updatable = false)
    private Long userId;
    @Column(name = "parent_comment_id", updatable = false)
    private Long parentCommentId;
    @Column(nullable = false, length = 1000)
    private String content;
    @JdbcType(LocalDateTimeJdbcType.class)
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;
    @JdbcType(LocalDateTimeJdbcType.class)
    @Column(name = "updated_at")
    private LocalDateTime updatedAt;
    @JdbcType(LocalDateTimeJdbcType.class)
    @Column(name = "deleted_at")
    private LocalDateTime deletedAt;

    public static PostComment create(Long postId, Long userId, Long parentCommentId, String content) {
        var comment = new PostComment();
        comment.content = normalizeContent(content);
        comment.postId = postId;
        comment.userId = userId;
        comment.parentCommentId = parentCommentId;
        comment.createdAt = UtcTime.toDatabase(Instant.now());
        return comment;
    }

    public static String normalizeContent(String content) {
        String normalized = content == null ? "" : content.trim();
        if (normalized.isEmpty() || normalized.length() > 1000) {
            throw new IllegalArgumentException("Comment content must be between 1 and 1000 characters.");
        }
        return normalized;
    }

    public boolean canBeDeletedBy(Long actorId, Long postAuthorId) {
        return Objects.equals(actorId, userId) || Objects.equals(actorId, postAuthorId);
    }
}
