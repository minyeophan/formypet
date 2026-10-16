package com.formypet.domain.notification.entity;

import jakarta.persistence.*;
import java.time.LocalDateTime;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.JdbcType;
import org.hibernate.type.descriptor.jdbc.LocalDateTimeJdbcType;

@Entity
@Table(name = "notifications")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Notification {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(name = "recipient_user_id", nullable = false, updatable = false)
    private Long recipientUserId;
    @Column(name = "actor_user_id", updatable = false)
    private Long actorUserId;
    @Column(name = "actor_nickname", length = 50, updatable = false)
    private String actorNickname;
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 40, updatable = false)
    private NotificationType type;
    @Column(name = "post_id", updatable = false)
    private Long postId;
    @Column(name = "comment_id", updatable = false)
    private Long commentId;
    @Column(nullable = false, length = 120, updatable = false)
    private String title;
    @Column(nullable = false, length = 500, updatable = false)
    private String body;
    @Column(name = "source_type", length = 30, updatable = false)
    private String sourceType;
    @Column(name = "source_id", updatable = false)
    private Long sourceId;
    // A schedule is local to the configured reminder timezone, not an instant.
    @JdbcType(LocalDateTimeJdbcType.class)
    @Column(name = "scheduled_for", updatable = false)
    private LocalDateTime scheduledFor;
    @JdbcType(LocalDateTimeJdbcType.class)
    @Column(name = "read_at")
    private LocalDateTime readAt;
    @JdbcType(LocalDateTimeJdbcType.class)
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    public static Notification activity(Long recipient, Long actor, String nickname, NotificationType type,
                                        Long post, Long comment, String title, String body, LocalDateTime createdAt) {
        var notification = new Notification();
        notification.recipientUserId = recipient;
        notification.actorUserId = actor;
        notification.actorNickname = nickname;
        notification.type = type;
        notification.postId = post;
        notification.commentId = comment;
        notification.title = title;
        notification.body = body;
        notification.createdAt = createdAt;
        return notification;
    }

    public void markRead(LocalDateTime at) {
        if (readAt == null) readAt = at;
    }
}
