package com.formypet.domain.community.entity;

import jakarta.persistence.*;
import lombok.*;
import java.util.List;

@Entity @Table(name = "post_polls")
@Getter @NoArgsConstructor(access = AccessLevel.PROTECTED)
public class PostPoll {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(name = "post_id", nullable = false, unique = true, updatable = false)
    private Long postId;
    @Column(nullable = false, length = 200)
    private String question;

    public static PostPoll create(Long postId, String question) {
        var poll = new PostPoll();
        poll.postId = postId;
        poll.question = question;
        return poll;
    }

    public static void validate(String question, List<String> options) {
        if (question == null || question.isBlank()) throw new IllegalArgumentException("Poll question is required.");
        if (options == null || options.size() < 2 || options.size() > 5) {
            throw new IllegalArgumentException("Poll options must contain 2 to 5 items.");
        }
        if (options.stream().anyMatch(option -> option == null || option.isBlank())) {
            throw new IllegalArgumentException("Poll options must not be blank.");
        }
    }
}
