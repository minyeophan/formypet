package com.formypet.domain.community.entity;

import jakarta.persistence.*;
import lombok.*;

@Entity @Table(name = "post_poll_options")
@Getter @NoArgsConstructor(access = AccessLevel.PROTECTED)
public class PostPollOption {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(name = "poll_id", nullable = false, updatable = false)
    private Long pollId;
    @Column(nullable = false, length = 100)
    private String label;
    @Column(name = "votes_count", nullable = false, updatable = false)
    private int votesCount;
    @Column(name = "sort_order", nullable = false)
    private int sortOrder;

    public static PostPollOption create(Long pollId, String label, int sortOrder) {
        var option = new PostPollOption();
        option.pollId = pollId;
        option.label = label;
        option.sortOrder = sortOrder;
        return option;
    }
}
