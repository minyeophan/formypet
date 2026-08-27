package com.petyilgi.notification;
import io.swagger.v3.oas.annotations.media.Schema;
@Schema(description = "알림 유형")
public enum NotificationType { COMMENT, REPLY, POST_LIKE, POLL_VOTE, ROUTINE_REMINDER, CARE_SCHEDULE_REMINDER }
