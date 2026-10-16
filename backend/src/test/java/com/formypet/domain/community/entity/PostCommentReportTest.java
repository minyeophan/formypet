package com.formypet.domain.community.entity;

import com.formypet.global.exception.ApiException;
import com.formypet.global.time.UtcTime;
import org.junit.jupiter.api.Test;
import java.time.Instant;
import static org.assertj.core.api.Assertions.*;

class PostCommentReportTest {
    @Test
    void reportTrimsDetailAndPreservesContentSnapshotAndUtc() {
        var before = UtcTime.toDatabase(Instant.now());
        var report = PostCommentReport.create(3L, 7L, "OTHER", " detail ", " original snapshot ");
        assertThat(report.getCommentId()).isEqualTo(3L);
        assertThat(report.getReporterUserId()).isEqualTo(7L);
        assertThat(report.getReason()).isEqualTo("OTHER");
        assertThat(report.getDetail()).isEqualTo("detail");
        assertThat(report.getContentSnapshot()).isEqualTo(" original snapshot ");
        assertThat(report.getCreatedAt()).isBetween(before, UtcTime.toDatabase(Instant.now()));
    }

    @Test
    void onlyOtherRequiresDetail() {
        assertThatThrownBy(() -> PostCommentReport.create(3L, 7L, "OTHER", null, "body"))
                .isInstanceOf(ApiException.class).hasMessage("Detail is required for OTHER reports.");
        assertThatThrownBy(() -> PostCommentReport.create(3L, 7L, "OTHER", " ", "body"))
                .isInstanceOf(ApiException.class);
        assertThat(PostCommentReport.create(3L, 7L, "SPAM", null, "body").getDetail()).isNull();
    }
}
