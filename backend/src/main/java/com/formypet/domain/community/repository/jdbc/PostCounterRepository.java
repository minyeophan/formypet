package com.formypet.domain.community.repository.jdbc;

import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

/** Atomic arithmetic preserves concurrent comments/likes without dirty entity counter writes. */
@Repository
@RequiredArgsConstructor
public class PostCounterRepository {
    private final JdbcTemplate jdbc;

    public void incrementComments(Long postId) {
        jdbc.update("UPDATE posts SET comments_count = comments_count + 1 WHERE id = ?", postId);
    }

    public void decrementComments(Long postId) {
        jdbc.update("UPDATE posts SET comments_count = GREATEST(comments_count - 1, 0) WHERE id = ?", postId);
    }

    public void incrementLikes(Long postId) {
        jdbc.update("UPDATE posts SET likes_count = likes_count + 1 WHERE id = ?", postId);
    }

    public void decrementLikes(Long postId) {
        jdbc.update("UPDATE posts SET likes_count = GREATEST(likes_count - 1, 0) WHERE id = ?", postId);
    }

    public void incrementVotes(Long optionId) {
        jdbc.update("UPDATE post_poll_options SET votes_count = votes_count + 1 WHERE id = ?", optionId);
    }

    public void decrementVotes(Long optionId) {
        jdbc.update("UPDATE post_poll_options SET votes_count = GREATEST(votes_count - 1, 0) WHERE id = ?", optionId);
    }
}
