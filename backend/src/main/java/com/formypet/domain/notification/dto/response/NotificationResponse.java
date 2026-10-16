package com.formypet.domain.notification.dto.response;

import com.formypet.domain.notification.entity.NotificationType;
import io.swagger.v3.oas.annotations.media.Schema;
import java.time.Instant;
import java.time.LocalDateTime;

public record NotificationResponse(Long id,
                                   @Schema(nullable = true, description = "예약 알림에는 null") Long actorUserId,
                                   @Schema(nullable = true, description = "예약 알림에는 null") String actorNickname,
                                   NotificationType type,
                                   @Schema(nullable = true, description = "예약 알림에는 null") Long postId,
                                   @Schema(nullable = true, description = "예약 알림에는 null") Long commentId, String sourceType, Long sourceId, LocalDateTime scheduledFor,
                                   String title, String body,
                                   Instant readAt,
                                   Instant createdAt) {}
