package com.formypet.domain.community.repository;

import com.formypet.domain.community.entity.PostCommentReport;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PostCommentReportRepository extends JpaRepository<PostCommentReport, Long> {
    boolean existsByCommentIdAndReporterUserId(Long commentId, Long reporterUserId);
}
