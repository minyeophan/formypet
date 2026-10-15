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
                "domain.pet.entity.Pet", "updatedAt",
                "domain.community.dto.response.PostResponse", "createdAt",
                "domain.community.dto.response.PostCommentResponse", "updatedAt",
                "domain.community.dto.response.MyActivityResponse$Item", "activityAt",
                "domain.notification.dto.response.NotificationResponse", "readAt",
                "domain.routine.dto.response.CareScheduleResponse", "createdAt",
                "domain.routine.dto.response.RoutineCompletionResponse", "completedAt").entrySet()) {
            var type = Class.forName("com.formypet." + entry.getKey());
            assertThat(type.getDeclaredField(entry.getValue()).getType())
                    .as(entry.getKey() + "." + entry.getValue()).isEqualTo(Instant.class);
        }
        assertThat(com.formypet.domain.notification.dto.response.NotificationResponse.class
                .getDeclaredField("scheduledFor").getType()).isEqualTo(LocalDateTime.class);
    }
}
