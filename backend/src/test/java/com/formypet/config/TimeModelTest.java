package com.formypet.config;

import java.time.Instant;
import java.time.LocalDateTime;
import java.util.Map;
import org.junit.jupiter.api.Test;
import static org.assertj.core.api.Assertions.assertThat;

class TimeModelTest {
    @Test
    void eventFieldsCarryAnInstantRatherThanAnUnspecifiedWallClock() throws Exception {
        for (var entry : Map.of(
                "auth.domain.User", "createdAt",
                "auth.domain.RefreshToken", "expiresAt",
                "auth.domain.OAuthAccount", "createdAt",
                "pet.domain.Pet", "updatedAt",
                "community.dto.PostResponse", "createdAt",
                "community.dto.PostCommentResponse", "updatedAt",
                "community.dto.MyActivityResponse$Item", "activityAt",
                "notification.dto.NotificationResponse", "readAt",
                "routine.dto.CareScheduleResponse", "createdAt",
                "routine.dto.RoutineCompletionResponse", "completedAt").entrySet()) {
            var type = Class.forName("com.formypet." + entry.getKey());
            assertThat(type.getDeclaredField(entry.getValue()).getType())
                    .as(entry.getKey() + "." + entry.getValue()).isEqualTo(Instant.class);
        }
        assertThat(com.formypet.notification.dto.NotificationResponse.class
                .getDeclaredField("scheduledFor").getType()).isEqualTo(LocalDateTime.class);
    }
}
