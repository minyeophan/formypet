package com.formypet.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.formypet.community.dto.PostCommentResponse;
import com.formypet.community.dto.PostCommentReportResponse;
import com.formypet.community.dto.PostResponse;
import com.formypet.community.dto.MyActivityResponse;
import com.formypet.notification.NotificationType;
import com.formypet.notification.dto.NotificationResponse;
import java.time.LocalDateTime;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.util.List;
import org.junit.jupiter.api.Test;
import static org.assertj.core.api.Assertions.assertThat;

class ActivityTimestampJsonTest {
    private final ObjectMapper mapper = new ObjectMapper().findAndRegisterModules()
            .disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);
    private final Instant storedUtc = Instant.parse("2026-10-03T15:54:32Z");

    @Test
    void reportCreationAlsoIdentifiesUtc() throws Exception {
        var report = new PostCommentReportResponse(1L, 2L, null, null, storedUtc);
        var json = mapper.readTree(mapper.writeValueAsString(report));
        assertThat(json.get("createdAt").asText()).isEqualTo("2026-10-03T15:54:32Z");
    }

    @Test
    void activityListAlsoMarksItsSortingTimestampAsUtc() throws Exception {
        var item = new MyActivityResponse.Item(null, storedUtc, null);
        var json = mapper.readTree(mapper.writeValueAsString(item));
        assertThat(json.get("activityAt").asText()).isEqualTo("2026-10-03T15:54:32Z");
    }

    @Test
    void postTimestampIdentifiesTheInstantWithoutChangingStoredWallTime() throws Exception {
        var post = PostResponse.of(1L, 2L, "test", null, "title", "FREE", null,
                "body", 0, 0, false, storedUtc, List.of(), null);
        var json = mapper.readTree(mapper.writeValueAsString(post));
        assertThat(json.get("createdAt").asText()).isEqualTo("2026-10-03T15:54:32Z");
        assertThat(OffsetDateTime.parse(json.get("createdAt").asText()).toInstant())
                .isEqualTo(OffsetDateTime.parse("2026-10-04T00:54:32+09:00").toInstant());
    }

    @Test
    void commentsMarkCreationAndEditsAsUtc() throws Exception {
        var comment = new PostCommentResponse(1L, 2L, "test", null, "body", storedUtc,
                storedUtc.plusSeconds(60), false, 0, null, 0, List.of(), null);
        var json = mapper.readTree(mapper.writeValueAsString(comment));
        assertThat(json.get("createdAt").asText()).isEqualTo("2026-10-03T15:54:32Z");
        assertThat(json.get("updatedAt").asText()).isEqualTo("2026-10-03T15:55:32Z");
    }

    @Test
    void notificationAuditTimesAreUtcButScheduledTimeRemainsLocal() throws Exception {
        var notification = new NotificationResponse(1L, null, null,
                NotificationType.CARE_SCHEDULE_REMINDER, null, null, "CARE_SCHEDULE", 2L,
                LocalDateTime.of(2026, 10, 4, 0, 54, 0), "title", "body", null, storedUtc);
        var json = mapper.readTree(mapper.writeValueAsString(notification));
        assertThat(json.get("createdAt").asText()).isEqualTo("2026-10-03T15:54:32Z");
        assertThat(json.get("readAt").isNull()).isTrue();
        assertThat(json.get("scheduledFor").asText()).isEqualTo("2026-10-04T00:54:00");
    }
}
