package com.formypet.domain.community.repository;

import com.formypet.domain.community.entity.PostComment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import java.time.LocalDateTime;

public interface PostCommentRepository extends JpaRepository<PostComment, Long> {
    @Modifying(flushAutomatically = true)
    @Query("update PostComment c set c.content = :content, c.updatedAt = :at "
            + "where c.id = :id and c.postId = :postId and c.deletedAt is null")
    int updateActive(Long id, Long postId, String content, LocalDateTime at);

    @Modifying(flushAutomatically = true)
    @Query("update PostComment c set c.deletedAt = :at "
            + "where c.id = :id and c.postId = :postId and c.deletedAt is null")
    int deleteActive(Long id, Long postId, LocalDateTime at);
}
