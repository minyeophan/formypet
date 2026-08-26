package com.petyilgi.notification.dto;
import com.petyilgi.notification.NotificationType;
import java.time.LocalDateTime;
public record NotificationResponse(Long id, Long actorUserId, String actorNickname, NotificationType type,
                                   Long postId, Long commentId, String title, String body,
                                   LocalDateTime readAt, LocalDateTime createdAt) {}
