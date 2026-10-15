package com.formypet.domain.community.repository.query;

import com.formypet.domain.community.dto.response.PostResponse;
import com.formypet.domain.community.dto.response.PostFeedResponse;
import com.formypet.common.time.UtcTime;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;
import java.time.Instant;
import java.util.*;
import java.time.LocalDateTime;
import java.util.Map;

/** API read projection joins community data with author and media metadata. */
@Repository
@RequiredArgsConstructor
public class PostProjectionRepository {
    private final JdbcTemplate jdbcTemplate;

    public Long authorId(Long postId) {
        return jdbcTemplate.queryForObject("SELECT user_id FROM posts WHERE id = ?", Long.class, postId);
    }

    public boolean visible(Long postId, Long viewer) {
        return jdbcTemplate.queryForObject("""
                SELECT COUNT(*) FROM posts p WHERE p.id = ? AND NOT EXISTS (
                    SELECT 1 FROM user_blocks b WHERE b.blocker_user_id = ? AND b.blocked_user_id = p.user_id)
                """, Integer.class, postId, viewer) > 0;
    }

    public int commentsCount(Long postId) {
        return jdbcTemplate.queryForObject("SELECT comments_count FROM posts WHERE id = ?", Integer.class, postId);
    }

    public int likesCount(Long postId) {
        return jdbcTemplate.queryForObject("SELECT likes_count FROM posts WHERE id = ?", Integer.class, postId);
    }

    public PostResponse findPostResponse(Long postId, Long currentUserId) {
        Map<String, Object> row = jdbcTemplate.queryForMap("""
                SELECT p.id, p.user_id, u.nickname AS author_nickname, p.title, p.category, p.pet_species, p.content,
                       p.likes_count, p.comments_count, p.created_at, u.profile_media_id,
                       EXISTS(SELECT 1 FROM post_likes pl WHERE pl.post_id = p.id AND pl.user_id = ?) AS liked
                FROM posts p
                JOIN users u ON u.id = p.user_id
                WHERE p.id = ?
                """, currentUserId, postId);
        return toPostResponse(row, currentUserId);
    }

    public PostResponse toPostResponse(Map<String, Object> row, Long currentUserId) {
        return toPostResponse(row, currentUserId, false);
    }

    /** Reaction callers already hold the post lock; do not return the snapshot from before that lock. */
    public PostResponse findCurrentPostResponse(Long postId, Long currentUserId) {
        Map<String, Object> row = jdbcTemplate.queryForMap("""
                SELECT p.id, p.user_id, u.nickname AS author_nickname, p.title, p.category, p.pet_species, p.content,
                       p.likes_count, p.comments_count, p.created_at, u.profile_media_id,
                       (pl.user_id IS NOT NULL) AS liked
                FROM posts p JOIN users u ON u.id = p.user_id
                LEFT JOIN post_likes pl ON pl.post_id = p.id AND pl.user_id = ?
                WHERE p.id = ? FOR SHARE
                """, currentUserId, postId);
        return toPostResponse(row, currentUserId, true);
    }

    private PostResponse toPostResponse(Map<String, Object> row, Long currentUserId, boolean currentRead) {
        Long postId = ((Number) row.get("id")).longValue();
        return PostResponse.of(
                postId,
                ((Number) row.get("user_id")).longValue(),
                (String) row.get("author_nickname"),
                row.get("profile_media_id") == null ? null
                        : "/api/v1/users/" + ((Number) row.get("user_id")).longValue() + "/profile-image",
                (String) row.get("title"),
                (String) row.get("category"),
                (String) row.get("pet_species"),
                (String) row.get("content"),
                ((Number) row.get("likes_count")).intValue(),
                ((Number) row.get("comments_count")).intValue(),
                toBoolean(row.get("liked")),
                normalizeDateTime(row.get("created_at")),
                mediaUrls(postId),
                pollResponse(postId, currentUserId, currentRead)
        );
    }

    private List<String> mediaUrls(Long postId) {
        return jdbcTemplate.queryForList("""
                SELECT mr.id
                FROM post_media pm
                JOIN media_resources mr ON mr.id = pm.media_id
                WHERE pm.post_id = ?
                ORDER BY pm.sort_order ASC
                """, Long.class, postId).stream()
                .map(id -> "/api/v1/public/media/" + id)
                .toList();
    }

    private PostResponse.PollResponse pollResponse(Long postId, Long currentUserId, boolean currentRead) {
        var polls = jdbcTemplate.queryForList("""
                SELECT id, question FROM post_polls WHERE post_id = ?
                """ + (currentRead ? " FOR SHARE" : ""), postId);
        if (polls.isEmpty()) {
            return null;
        }
        Map<String, Object> poll = polls.getFirst();
        Long pollId = ((Number) poll.get("id")).longValue();
        List<PostResponse.PollOptionResponse> options = jdbcTemplate.queryForList("""
                SELECT ppo.id, ppo.label, ppo.votes_count, (ppv.user_id IS NOT NULL) AS voted_by_me
                FROM post_poll_options ppo
                LEFT JOIN post_poll_votes ppv ON ppv.poll_id = ppo.poll_id
                    AND ppv.user_id = ? AND ppv.option_id = ppo.id
                WHERE ppo.poll_id = ?
                ORDER BY ppo.sort_order ASC
                """ + (currentRead ? " FOR SHARE" : ""), currentUserId, pollId).stream()
                .map(row -> new PostResponse.PollOptionResponse(
                        ((Number) row.get("id")).longValue(),
                        (String) row.get("label"),
                        ((Number) row.get("votes_count")).intValue(),
                        toBoolean(row.get("voted_by_me"))
                ))
                .toList();
        return new PostResponse.PollResponse(pollId, (String) poll.get("question"), options);
    }

    private Instant normalizeDateTime(Object value) {
        return UtcTime.fromDatabase(value);
    }

    private boolean toBoolean(Object value) {
        if (value instanceof Boolean bool) {
            return bool;
        }
        return ((Number) value).intValue() == 1;
    }

    public com.formypet.domain.community.dto.response.MyActivityResponse myActivities(
            Long viewer, String type, LocalDateTime cursorAt, Long cursorId, int limit) {


        String activity = switch (type) {
            case "written" -> """
                SELECT id AS post_id, created_at AS activity_at,
                       NULL AS comment_id, NULL AS parent_id, NULL AS comment_content
                FROM posts WHERE user_id = ?
                """;
            case "liked" -> """
                SELECT post_id, created_at AS activity_at,
                       NULL AS comment_id, NULL AS parent_id, NULL AS comment_content
                FROM post_likes WHERE user_id = ?
                """;
            default -> """
                SELECT post_id, created_at AS activity_at, id AS comment_id,
                       parent_comment_id AS parent_id, content AS comment_content
                FROM (
                    SELECT pc.*, ROW_NUMBER() OVER (
                        PARTITION BY post_id ORDER BY created_at DESC, id DESC) AS rn
                    FROM post_comments pc WHERE user_id = ? AND deleted_at IS NULL
                ) ranked WHERE rn = 1
                """;
        };
        StringBuilder sql = new StringBuilder("""
            SELECT p.id, p.user_id, u.nickname AS author_nickname, p.title, p.category,
                   p.pet_species, p.content, p.likes_count, p.comments_count, p.created_at,
                   u.profile_media_id, a.activity_at, a.comment_id, a.parent_id, a.comment_content,
                   EXISTS(SELECT 1 FROM post_likes pl WHERE pl.post_id = p.id AND pl.user_id = ?) AS liked
            FROM (
            """).append(activity).append("""
            ) a JOIN posts p ON p.id = a.post_id JOIN users u ON u.id = p.user_id WHERE 1 = 1
            """);
        List<Object> params = new ArrayList<>(List.of(viewer, viewer));
        appendBlockFilter(sql, params, viewer);
        if (cursorAt != null) {
            sql.append(" AND (a.activity_at < ? OR (a.activity_at = ? AND p.id < ?))");
            params.addAll(List.of(cursorAt, cursorAt, cursorId));
        }
        sql.append(" ORDER BY a.activity_at DESC, p.id DESC LIMIT ?");
        params.add(limit + 1);
        var rows = jdbcTemplate.queryForList(sql.toString(), params.toArray());
        boolean more = rows.size() > limit;
        var items = rows.stream().limit(limit).map(row -> {
            Long commentId = row.get("comment_id") instanceof Number n ? n.longValue() : null;
            Long parentId = row.get("parent_id") instanceof Number n ? n.longValue() : null;
            var comment = commentId == null ? null :
                    new com.formypet.domain.community.dto.response.MyActivityResponse.Comment(commentId, parentId,
                            (String) row.get("comment_content"));
            return new com.formypet.domain.community.dto.response.MyActivityResponse.Item(toPostResponse(row, viewer),
                    UtcTime.fromDatabase(row.get("activity_at")), comment);
        }).toList();
        String next = null;
        if (more) {
            var last = items.getLast();
            next = Base64.getUrlEncoder().withoutPadding().encodeToString(
                    (type + "|" + UtcTime.toDatabase(last.activityAt()) + "|" + last.post().id())
                            .getBytes(java.nio.charset.StandardCharsets.UTF_8));
        }
        return new com.formypet.domain.community.dto.response.MyActivityResponse(items, next);
    }

    public PostFeedResponse feed(Long viewer, String normalizedKeyword, String category, String normalizedSort, Integer cursorLikes, Long cursorId, int pageSize) {
        List<Object> params = new ArrayList<>();
        StringBuilder sql = new StringBuilder("""
                SELECT p.id, p.user_id, u.nickname AS author_nickname, p.title, p.category, p.pet_species, p.content,
                       p.likes_count, p.comments_count, p.created_at, u.profile_media_id,
                       EXISTS(SELECT 1 FROM post_likes pl WHERE pl.post_id = p.id AND pl.user_id = ?) AS liked
                FROM posts p
                JOIN users u ON u.id = p.user_id
                WHERE 1 = 1
                """);
        params.add(viewer);
        appendBlockFilter(sql, params, viewer);
        if (category != null && !category.isBlank()) {
            sql.append(" AND p.category = ?");
            params.add(category);
        }
        if (normalizedKeyword != null) {
            String pattern = "%" + escapeLikeKeyword(normalizedKeyword) + "%";
            sql.append(" AND (p.title LIKE ? ESCAPE '!' OR p.content LIKE ? ESCAPE '!')");
            params.add(pattern);
            params.add(pattern);
        }
        if (cursorId != null) {
            if ("popular".equals(normalizedSort)) {
                sql.append(" AND (p.likes_count < ? OR (p.likes_count = ? AND p.id < ?))");
                params.addAll(List.of(cursorLikes, cursorLikes, cursorId));
            } else {
                sql.append(" AND p.id < ?");
                params.add(cursorId);
            }
        }
        if ("popular".equals(normalizedSort)) {
            sql.append(" ORDER BY p.likes_count DESC, p.id DESC LIMIT ?");
        } else {
            sql.append(" ORDER BY p.id DESC LIMIT ?");
        }
        params.add(pageSize + 1);

        List<Map<String, Object>> fetchedRows = jdbcTemplate.queryForList(sql.toString(), params.toArray());
        boolean hasNext = fetchedRows.size() > pageSize;
        List<Map<String, Object>> pageRows = hasNext ? fetchedRows.subList(0, pageSize) : fetchedRows;
        List<PostResponse> items = pageRows.stream()
                .map(row -> toPostResponse(row, viewer))
                .toList();
        String nextCursor = hasNext ? cursorFor(items.getLast(), normalizedSort) : null;
        return PostFeedResponse.of(items, nextCursor);
    }

    private void appendBlockFilter(StringBuilder sql, List<Object> params, Long viewer) {
        sql.append(" AND NOT EXISTS (SELECT 1 FROM user_blocks b WHERE b.blocker_user_id = ? AND b.blocked_user_id = p.user_id)");
        params.add(viewer);
    }

    private String cursorFor(PostResponse post, String sort) {
        if ("popular".equals(sort)) {
            return post.likesCount() + ":" + post.id();
        }
        return post.id().toString();
    }

    private String escapeLikeKeyword(String keyword) {
        return keyword.replace("!", "!!")
                .replace("%", "!%")
                .replace("_", "!_");
    }
}
