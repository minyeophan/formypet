package com.formypet.domain.community.repository.jdbc;

import com.formypet.domain.community.entity.PostLike;
import com.formypet.domain.community.entity.PostPollVote;
import lombok.RequiredArgsConstructor;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

/**
 * Try the unique insert before reading a reaction. Locking an absent composite key under
 * REPEATABLE READ takes a gap lock that can deadlock unrelated posts. JDBC also permits
 * handling just the duplicate without leaving a failed insert in the JPA persistence context.
 */
@Repository
@RequiredArgsConstructor
public class ReactionInsertRepository {
    private final JdbcTemplate jdbc;

    public boolean likeIfAbsent(PostLike like) {
        try {
            jdbc.update("INSERT INTO post_likes(user_id,post_id,created_at) VALUES (?,?,?)",
                    like.getUserId(), like.getPostId(), like.getCreatedAt());
            return true;
        } catch (DuplicateKeyException duplicate) {
            return false;
        }
    }

    public boolean voteIfAbsent(PostPollVote vote) {
        try {
            jdbc.update("INSERT INTO post_poll_votes(poll_id,user_id,option_id,created_at,updated_at) VALUES (?,?,?,?,?)",
                    vote.getPollId(), vote.getUserId(), vote.getOptionId(), vote.getCreatedAt(), vote.getUpdatedAt());
            return true;
        } catch (DuplicateKeyException duplicate) {
            return false;
        }
    }
}
