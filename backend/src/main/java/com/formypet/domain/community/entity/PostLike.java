package com.formypet.domain.community.entity;

import com.formypet.global.time.UtcTime;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.JdbcType;
import org.hibernate.type.descriptor.jdbc.LocalDateTimeJdbcType;
import java.io.Serializable;
import java.time.Instant;
import java.time.LocalDateTime;

@Entity @Table(name = "post_likes") @IdClass(PostLike.Key.class)
@Getter @NoArgsConstructor(access = AccessLevel.PROTECTED)
public class PostLike {
    @Id @Column(name = "user_id")
    private Long userId;
    @Id @Column(name = "post_id")
    private Long postId;
    @JdbcType(LocalDateTimeJdbcType.class)
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    public static PostLike create(Long userId, Long postId) {
        var like = new PostLike();
        like.userId = userId;
        like.postId = postId;
        like.createdAt = UtcTime.toDatabase(Instant.now());
        return like;
    }

    @NoArgsConstructor @AllArgsConstructor @EqualsAndHashCode
    public static class Key implements Serializable {
        private Long userId;
        private Long postId;
    }
}
