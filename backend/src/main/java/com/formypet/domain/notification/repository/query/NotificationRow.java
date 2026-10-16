package com.formypet.domain.notification.repository.query;

import java.time.LocalDateTime;

/** Scalar projection avoids stale managed rows after atomic read mutations. */
public record NotificationRow(Long id, Long actorUserId, String actorNickname, String type,
                              Long postId, Long commentId, String sourceType, Long sourceId,
                              LocalDateTime scheduledFor, String title, String body,
                              LocalDateTime readAt, LocalDateTime createdAt) {}
