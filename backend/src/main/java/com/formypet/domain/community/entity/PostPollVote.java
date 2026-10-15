package com.formypet.domain.community.entity;

import com.formypet.common.time.UtcTime;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.JdbcType;
import org.hibernate.type.descriptor.jdbc.LocalDateTimeJdbcType;
import java.io.Serializable;
import java.time.Instant;
import java.time.LocalDateTime;
import java.util.Objects;

@Entity @Table(name = "post_poll_votes") @IdClass(PostPollVote.Key.class)
@Getter @NoArgsConstructor(access = AccessLevel.PROTECTED)
public class PostPollVote {
    @Id @Column(name = "poll_id")
    private Long pollId;
    @Id @Column(name = "user_id")
    private Long userId;
    @Column(name = "option_id", nullable = false)
    private Long optionId;
    @JdbcType(LocalDateTimeJdbcType.class)
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;
    @JdbcType(LocalDateTimeJdbcType.class)
    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    public static PostPollVote create(Long pollId, Long userId, Long optionId) {
        var vote = new PostPollVote();
        vote.pollId = pollId;
        vote.userId = userId;
        vote.optionId = optionId;
        vote.createdAt = UtcTime.toDatabase(Instant.now());
        vote.updatedAt = vote.createdAt;
        return vote;
    }

    public boolean changeOption(Long optionId) {
        if (Objects.equals(this.optionId, optionId)) return false;
        this.optionId = optionId;
        this.updatedAt = UtcTime.toDatabase(Instant.now());
        return true;
    }

    @NoArgsConstructor @AllArgsConstructor @EqualsAndHashCode
    public static class Key implements Serializable {
        private Long pollId;
        private Long userId;
    }
}
