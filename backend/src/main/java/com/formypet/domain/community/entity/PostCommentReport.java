package com.formypet.domain.community.entity;

import com.formypet.common.exception.ApiException;
import com.formypet.common.time.UtcTime;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.JdbcType;
import org.hibernate.type.descriptor.jdbc.LocalDateTimeJdbcType;
import org.springframework.http.HttpStatus;
import java.time.Instant;
import java.time.LocalDateTime;

@Entity
@Table(name = "post_comment_reports", uniqueConstraints =
        @UniqueConstraint(name = "uk_post_comment_reporter", columnNames = {"comment_id", "reporter_user_id"}))
@Getter @NoArgsConstructor(access = AccessLevel.PROTECTED)
public class PostCommentReport {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(name = "comment_id", nullable = false, updatable = false)
    private Long commentId;
    @Column(name = "reporter_user_id", nullable = false, updatable = false)
    private Long reporterUserId;
    @Column(nullable = false, length = 30, updatable = false)
    private String reason;
    @Column(length = 500, updatable = false)
    private String detail;
    @Column(name = "content_snapshot", nullable = false, length = 1000, updatable = false)
    private String contentSnapshot;
    @JdbcType(LocalDateTimeJdbcType.class)
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    public static PostCommentReport create(Long commentId, Long reporterUserId, String reason,
                                           String detail, String contentSnapshot) {
        String normalized = detail == null ? null : detail.trim();
        if ("OTHER".equals(reason) && (normalized == null || normalized.isEmpty())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "comment-report-detail-required",
                    "Invalid Comment Report", "Detail is required for OTHER reports.",
                    "COMMENT_REPORT_DETAIL_REQUIRED");
        }
        var report = new PostCommentReport();
        report.commentId = commentId;
        report.reporterUserId = reporterUserId;
        report.reason = reason;
        report.detail = normalized;
        report.contentSnapshot = contentSnapshot;
        report.createdAt = UtcTime.toDatabase(Instant.now());
        return report;
    }
}
