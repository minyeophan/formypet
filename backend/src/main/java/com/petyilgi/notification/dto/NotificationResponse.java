package com.petyilgi.notification.dto;
import com.petyilgi.notification.NotificationType;
import java.time.LocalDateTime;
import io.swagger.v3.oas.annotations.media.Schema;
public record NotificationResponse(Long id,
                                   @Schema(nullable = true, description = "예약 알림에는 null") Long actorUserId,
                                   @Schema(nullable = true, description = "예약 알림에는 null") String actorNickname,
                                   NotificationType type,
                                   @Schema(nullable = true, description = "예약 알림에는 null") Long postId,
                                   @Schema(nullable = true, description = "예약 알림에는 null") Long commentId, String sourceType, Long sourceId, LocalDateTime scheduledFor,
                                   String title, String body,
                                   LocalDateTime readAt, LocalDateTime createdAt) {}
