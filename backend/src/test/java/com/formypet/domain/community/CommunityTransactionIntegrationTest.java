package com.formypet.domain.community;

import com.formypet.global.exception.ApiException;
import com.formypet.domain.community.dto.*;
import com.formypet.domain.community.dto.request.*;
import com.formypet.domain.community.dto.response.*;
import com.formypet.domain.community.service.CommunityService;
import com.formypet.support.IntegrationTestSupport;
import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.support.TransactionTemplate;
import java.util.*;
import java.util.concurrent.*;
import java.util.function.Supplier;
import static org.assertj.core.api.Assertions.*;

class CommunityTransactionIntegrationTest extends IntegrationTestSupport {
    @Autowired CommunityService service;
    @Autowired JdbcTemplate jdbc;
    @Autowired TransactionTemplate transactions;
    private final List<Long> users = new ArrayList<>();
    private Long author;
    private Long actor;
    private PostResponse post;

    @BeforeEach
    void seed() {
        author = user();
        actor = user();
        post = service.create(author, new PostCreateRequest("race", "FREE", "body", null,
                new PostCreateRequest.PollCreateRequest("question", List.of("one", "two"))), List.of());
    }

    @AfterEach
    void cleanup() {
        for (Long id : users) jdbc.update("DELETE FROM users WHERE id=?", id);
        users.clear();
    }

    private Long user() {
        String email = UUID.randomUUID() + "@community-jpa.test";
        jdbc.update("INSERT INTO users(email,password_hash,nickname) VALUES (?,'test','test')", email);
        Long id = jdbc.queryForObject("SELECT id FROM users WHERE email=?", Long.class, email);
        users.add(id);
        return id;
    }

    @Test @Timeout(30)
    void overlappingTogglesUseCurrentReadsAfterPostLock() throws Exception {
        var results = race(List.of(() -> service.toggleLike(actor, post.id()),
                () -> service.toggleLike(actor, post.id())));
        assertThat(results).allMatch(value -> value instanceof PostLikeResponse);
        assertThat(results.stream().map(value -> ((PostLikeResponse) value).liked())).containsExactlyInAnyOrder(true, false);
        assertThat(count("SELECT COUNT(*) FROM post_likes WHERE post_id=?", post.id())).isZero();
        assertThat(count("SELECT likes_count FROM posts WHERE id=?", post.id())).isZero();
    }

    @Test @Timeout(30)
    void differentUsersDoNotLoseLikeIncrements() throws Exception {
        Long other = user();
        var results = race(List.of(() -> service.toggleLike(actor, post.id()),
                () -> service.toggleLike(other, post.id())));
        assertThat(results).allMatch(value -> value instanceof PostLikeResponse response && response.liked());
        assertThat(count("SELECT COUNT(*) FROM post_likes WHERE post_id=?", post.id())).isEqualTo(2);
        assertThat(count("SELECT likes_count FROM posts WHERE id=?", post.id())).isEqualTo(2);
    }

    @Test @Timeout(30)
    void overlappingVotesKeepOneVoteAndOneTotalCount() throws Exception {
        Long first = post.poll().options().getFirst().id();
        Long second = post.poll().options().getLast().id();
        var results = race(List.of(() -> service.vote(actor, post.id(), first),
                () -> service.vote(actor, post.id(), second)));
        assertThat(results).allMatch(value -> value instanceof PostResponse);
        assertThat(count("SELECT COUNT(*) FROM post_poll_votes WHERE poll_id=?", post.poll().id())).isEqualTo(1);
        assertThat(count("SELECT SUM(votes_count) FROM post_poll_options WHERE poll_id=?", post.poll().id())).isEqualTo(1);
        Long selected = jdbc.queryForObject("SELECT option_id FROM post_poll_votes WHERE poll_id=? AND user_id=?",
                Long.class, post.poll().id(), actor);
        assertThat(count("SELECT votes_count FROM post_poll_options WHERE id=?", selected)).isEqualTo(1);
    }

    @Test @Timeout(30)
    void independentPostsCanBeLikedConcurrently() throws Exception {
        var otherPost = service.create(author, new PostCreateRequest("other", "FREE", "body", null, null), List.of());
        var results = race(List.of(() -> service.toggleLike(actor, post.id()),
                () -> service.toggleLike(actor, otherPost.id())));
        assertThat(results).allMatch(value -> value instanceof PostLikeResponse response && response.liked());
        assertThat(count("SELECT likes_count FROM posts WHERE id=?", post.id())).isEqualTo(1);
        assertThat(count("SELECT likes_count FROM posts WHERE id=?", otherPost.id())).isEqualTo(1);
    }

    @Test @Timeout(30)
    void independentPollsCanBeVotedConcurrently() throws Exception {
        var other = service.create(author, new PostCreateRequest("other poll", "FREE", "body", null,
                new PostCreateRequest.PollCreateRequest("question", List.of("one", "two"))), List.of());
        var results = race(List.of(() -> service.vote(actor, post.id(), post.poll().options().getFirst().id()),
                () -> service.vote(actor, other.id(), other.poll().options().getFirst().id())));
        assertThat(results).allMatch(value -> value instanceof PostResponse response
                && response.poll().options().getFirst().votedByMe()
                && response.poll().options().getFirst().votesCount() == 1);
    }

    @Test
    void blockedLikeCanBeRemovedButNewAttemptRollsBackItsInsert() {
        service.toggleLike(actor, post.id());
        jdbc.update("INSERT INTO user_blocks(blocker_user_id,blocked_user_id) VALUES (?,?)", actor, author);
        assertThat(service.toggleLike(actor, post.id()).liked()).isFalse();
        assertThatThrownBy(() -> service.toggleLike(actor, post.id()))
                .isInstanceOfSatisfying(ApiException.class, error -> assertThat(error.errorCode()).isEqualTo("POST_NOT_FOUND"));
        assertThat(count("SELECT COUNT(*) FROM post_likes WHERE post_id=?", post.id())).isZero();
        assertThat(count("SELECT likes_count FROM posts WHERE id=?", post.id())).isZero();
    }

    @Test @Timeout(30)
    void overlappingSoftDeletesDecrementOnlyOnce() throws Exception {
        Long commentId = service.createComment(actor, post.id(), new PostCommentCreateRequest("body", null)).id();
        var results = race(List.of(() -> { service.deleteComment(actor, post.id(), commentId); return "deleted"; },
                () -> { service.deleteComment(author, post.id(), commentId); return "deleted"; }));
        assertThat(results.stream().filter("deleted"::equals)).hasSize(1);
        assertThat(results.stream().filter(value -> value instanceof ApiException error
                && error.errorCode().equals("COMMENT_NOT_FOUND"))).hasSize(1);
        assertThat(count("SELECT comments_count FROM posts WHERE id=?", post.id())).isZero();
        assertThat(count("SELECT COUNT(*) FROM post_comments WHERE id=? AND deleted_at IS NOT NULL", commentId)).isEqualTo(1);
    }

    @Test @Timeout(30)
    void identicalConcurrentVotesBothReturnTheCommittedSelection() throws Exception {
        Long optionId = post.poll().options().getFirst().id();
        var results = race(List.of(() -> service.vote(actor, post.id(), optionId),
                () -> service.vote(actor, post.id(), optionId)));
        assertThat(results).allMatch(value -> value instanceof PostResponse);
        for (Object result : results) {
            var selected = ((PostResponse) result).poll().options().stream()
                    .filter(option -> option.id().equals(optionId)).findFirst().orElseThrow();
            assertThat(selected.votedByMe()).isTrue();
            assertThat(selected.votesCount()).isEqualTo(1);
        }
    }

    @Test @Timeout(30)
    void overlappingReportsReturnOneCreatedAndOneConflict() throws Exception {
        Long commentId = service.createComment(author, post.id(), new PostCommentCreateRequest("snapshot", null)).id();
        var request = new PostCommentReportRequest(PostCommentReportReason.SPAM, null);
        var results = race(List.of(() -> service.reportComment(actor, post.id(), commentId, request),
                () -> service.reportComment(actor, post.id(), commentId, request)));
        assertThat(results.stream().filter(value -> value instanceof PostCommentReportResponse)).hasSize(1);
        assertThat(results.stream().filter(value -> value instanceof ApiException error
                && error.errorCode().equals("DUPLICATE_COMMENT_REPORT"))).hasSize(1);
        assertThat(count("SELECT COUNT(*) FROM post_comment_reports WHERE comment_id=?", commentId)).isEqualTo(1);
    }

    @Test
    void rollbackRemovesFlushedPostRelationsCommentCountersAndNotifications() {
        int notifications = count("SELECT COUNT(*) FROM notifications WHERE recipient_user_id=?", author);
        Long rolledBackId = transactions.execute(status -> {
            var created = service.create(author, new PostCreateRequest("rollback", "FREE", "body", null,
                    new PostCreateRequest.PollCreateRequest("question", List.of("one", "two"))), List.of());
            service.toggleLike(actor, created.id());
            service.vote(actor, created.id(), created.poll().options().getFirst().id());
            Long commentId = service.createComment(actor, created.id(), new PostCommentCreateRequest("body", null)).id();
            service.reportComment(author, created.id(), commentId,
                    new PostCommentReportRequest(PostCommentReportReason.SPAM, null));
            assertThat(count("SELECT COUNT(*) FROM posts WHERE id=?", created.id())).isEqualTo(1);
            status.setRollbackOnly();
            return created.id();
        });
        assertThat(count("SELECT COUNT(*) FROM posts WHERE id=?", rolledBackId)).isZero();
        assertThat(count("SELECT COUNT(*) FROM post_polls WHERE post_id=?", rolledBackId)).isZero();
        assertThat(count("SELECT COUNT(*) FROM post_likes WHERE post_id=?", rolledBackId)).isZero();
        assertThat(count("SELECT COUNT(*) FROM post_comments WHERE post_id=?", rolledBackId)).isZero();
        assertThat(count("SELECT COUNT(*) FROM notifications WHERE recipient_user_id=?", author)).isEqualTo(notifications);
    }

    private int count(String sql, Long id) { return jdbc.queryForObject(sql, Integer.class, id); }

    private List<Object> race(List<Supplier<?>> actions) throws Exception {
        var ready = new CyclicBarrier(actions.size());
        var executor = Executors.newFixedThreadPool(actions.size());
        try {
            List<Future<Object>> futures = new ArrayList<>();
            for (Supplier<?> action : actions) futures.add(executor.submit(() -> {
                try {
                    return transactions.execute(status -> {
                        // Both transactions establish a repeatable-read snapshot before competing for locks.
                        count("SELECT COUNT(*) FROM posts WHERE id=?", post.id());
                        try { ready.await(5, TimeUnit.SECONDS); }
                        catch (Exception error) { throw new IllegalStateException(error); }
                        return action.get();
                    });
                } catch (RuntimeException error) { return error; }
            }));
            List<Object> results = new ArrayList<>();
            for (Future<Object> future : futures) results.add(future.get(15, TimeUnit.SECONDS));
            return results;
        } finally {
            executor.shutdownNow();
            assertThat(executor.awaitTermination(5, TimeUnit.SECONDS)).isTrue();
        }
    }
}
