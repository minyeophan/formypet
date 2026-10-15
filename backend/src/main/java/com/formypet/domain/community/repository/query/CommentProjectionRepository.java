package com.formypet.domain.community.repository.query;

import com.formypet.domain.community.dto.response.PostCommentResponse;
import com.formypet.domain.community.dto.response.PostCommentFeedResponse;
import com.formypet.common.exception.ApiException;
import com.formypet.common.exception.InvalidInputException;
import com.formypet.common.time.UtcTime;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;
import org.springframework.http.HttpStatus;
import java.time.Instant;
import java.util.*;

/** Read projection preserves root tombstones, blocked authors and per-root reply windows. */
@Repository
@RequiredArgsConstructor
public class CommentProjectionRepository {
    private final JdbcTemplate jdbcTemplate;

    public record CommentSnapshot(Long id, Long postId, Long userId, Long parentCommentId,
                                  String content, Instant deletedAt) {}

    public CommentSnapshot requireSnapshot(Long commentId) {
        Map<String, Object> row = requireCommentAnyPost(commentId);
        return new CommentSnapshot(idOf(row), ((Number) row.get("post_id")).longValue(),
                ((Number) row.get("user_id")).longValue(), row.get("parent_comment_id") == null ? null
                : ((Number) row.get("parent_comment_id")).longValue(), (String) row.get("content"),
                normalizeDateTime(row.get("deleted_at")));
    }
    public PostCommentFeedResponse comments(Long viewer, Long postId, String cursor, int limit, int replyLimit) {


        int pageSize = Math.max(1, Math.min(limit, 50));
        int nestedPageSize = validateReplyLimit(replyLimit);
        int commentsCount = commentsCount(postId);
        List<Object> params = new ArrayList<>(List.of(postId));
        StringBuilder sql = new StringBuilder("""
                SELECT pc.id, pc.user_id, pc.parent_comment_id, u.nickname AS author_nickname, u.profile_media_id,
                       pc.content, pc.created_at, pc.updated_at, pc.deleted_at,
                       (SELECT COUNT(*) FROM post_comments child
                        WHERE child.parent_comment_id = pc.id AND child.deleted_at IS NULL) AS reply_count
                FROM post_comments pc
                JOIN users u ON u.id = pc.user_id
                WHERE pc.post_id = ? AND pc.parent_comment_id IS NULL
                  AND (pc.deleted_at IS NULL OR EXISTS (
                      SELECT 1 FROM post_comments child
                      WHERE child.parent_comment_id = pc.id AND child.deleted_at IS NULL))
                """);
        if (cursor != null && !cursor.isBlank()) {
            sql.append(" AND pc.id < ?");
            params.add(parseCommentCursor(cursor));
        }
        sql.append(" ORDER BY pc.id DESC LIMIT ?");
        params.add(pageSize + 1);
        List<Map<String, Object>> rows = jdbcTemplate.queryForList(sql.toString(), params.toArray());
        boolean hasNext = rows.size() > pageSize;
        if (hasNext) rows = new ArrayList<>(rows.subList(0, pageSize));
        Set<Long> blocked = blockedAuthors(viewer);
        maskBlockedComments(rows, blocked);
        Map<Long, List<PostCommentResponse>> replies = loadReplies(rows, nestedPageSize, commentsCount, blocked);
        List<PostCommentResponse> items = rows.stream()
                .map(row -> rootCommentResponse(row, commentsCount, replies.getOrDefault(idOf(row), List.of())))
                .toList();
        String nextCursor = hasNext ? items.getLast().id().toString() : null;
        return PostCommentFeedResponse.of(items, nextCursor);
    }

    public PostCommentResponse commentThread(Long viewer, Long postId, Long commentId, int replyLimit) {


        Map<String, Object> row = requireComment(postId, commentId);
        if (row.get("deleted_at") != null && ((Number) row.get("reply_count")).intValue() == 0) {
            throw commentNotFound();
        }
        if (row.get("parent_comment_id") != null) throw invalidCommentParent();
        int commentsCount = commentsCount(postId);
        Set<Long> blocked = blockedAuthors(viewer);
        maskBlockedComments(List.of(row), blocked);
        List<PostCommentResponse> replies = loadReplies(List.of(row), validateReplyLimit(replyLimit), commentsCount, blocked)
                .getOrDefault(commentId, List.of());
        return rootCommentResponse(row, commentsCount, replies);
    }

    public PostCommentFeedResponse replies(Long viewer, Long postId, Long commentId, String cursor, int limit) {


        Map<String, Object> parent = requireComment(postId, commentId);
        if (parent.get("deleted_at") != null && ((Number) parent.get("reply_count")).intValue() == 0) {
            throw commentNotFound();
        }
        if (parent.get("parent_comment_id") != null) throw invalidCommentParent();
        int pageSize = Math.max(1, Math.min(limit, 20));
        int commentsCount = commentsCount(postId);
        List<Object> params = new ArrayList<>(List.of(postId, commentId));
        StringBuilder sql = new StringBuilder("""
                SELECT pc.id, pc.user_id, pc.parent_comment_id, u.nickname AS author_nickname, u.profile_media_id,
                       pc.content, pc.created_at, pc.updated_at, pc.deleted_at, 0 AS reply_count
                FROM post_comments pc
                JOIN users u ON u.id = pc.user_id
                WHERE pc.post_id = ? AND pc.parent_comment_id = ? AND pc.deleted_at IS NULL
                """);
        if (cursor != null && !cursor.isBlank()) {
            sql.append(" AND pc.id < ?");
            params.add(parseCommentCursor(cursor));
        }
        sql.append(" ORDER BY pc.id DESC LIMIT ?");
        params.add(pageSize + 1);
        List<Map<String, Object>> rows = jdbcTemplate.queryForList(sql.toString(), params.toArray());
        boolean hasNext = rows.size() > pageSize;
        if (hasNext) rows = new ArrayList<>(rows.subList(0, pageSize));
        Collections.reverse(rows);
        maskBlockedComments(rows, blockedAuthors(viewer));
        List<PostCommentResponse> items = rows.stream().map(row -> leafCommentResponse(row, commentsCount)).toList();
        String nextCursor = hasNext && !items.isEmpty() ? items.getFirst().id().toString() : null;
        return PostCommentFeedResponse.of(items, nextCursor);
    }

    public PostCommentResponse findCommentResponse(Long commentId, int commentsCount) {
        Map<String, Object> row = jdbcTemplate.queryForMap("""
                SELECT pc.id, pc.user_id, pc.parent_comment_id, u.nickname AS author_nickname, u.profile_media_id,
                       pc.content, pc.created_at, pc.updated_at, pc.deleted_at, 0 AS reply_count
                FROM post_comments pc
                JOIN users u ON u.id = pc.user_id
                WHERE pc.id = ?
                """, commentId);
        return leafCommentResponse(row, commentsCount);
    }

    private PostCommentResponse leafCommentResponse(Map<String, Object> row, int commentsCount) {
        if (row.get("deleted_at") != null || Boolean.TRUE.equals(row.get("blocked"))) {
            return tombstoneCommentResponse(row, commentsCount, List.of());
        }
        return new PostCommentResponse(
                ((Number) row.get("id")).longValue(),
                ((Number) row.get("user_id")).longValue(),
                (String) row.get("author_nickname"),
                commentAuthorProfileImageUrl(row),
                (String) row.get("content"),
                normalizeDateTime(row.get("created_at")),
                normalizeDateTime(row.get("updated_at")),
                row.get("deleted_at") != null,
                commentsCount,
                row.get("parent_comment_id") == null ? null : ((Number) row.get("parent_comment_id")).longValue(),
                0,
                List.of(),
                null
        );
    }

    private PostCommentResponse rootCommentResponse(Map<String, Object> row, int commentsCount,
                                                     List<PostCommentResponse> replies) {
        if (row.get("deleted_at") != null || Boolean.TRUE.equals(row.get("blocked"))) {
            return tombstoneCommentResponse(row, commentsCount, replies);
        }
        int replyCount = ((Number) row.get("reply_count")).intValue();
        String nextCursor = replyCount > replies.size() && !replies.isEmpty()
                ? replies.getFirst().id().toString() : null;
        return new PostCommentResponse(idOf(row), ((Number) row.get("user_id")).longValue(),
                (String) row.get("author_nickname"), commentAuthorProfileImageUrl(row),
                (String) row.get("content"), normalizeDateTime(row.get("created_at")),
                normalizeDateTime(row.get("updated_at")), row.get("deleted_at") != null, commentsCount,
                null, replyCount, replies, nextCursor);
    }

    private PostCommentResponse tombstoneCommentResponse(Map<String, Object> row, int commentsCount,
                                                          List<PostCommentResponse> replies) {
        int replyCount = ((Number) row.get("reply_count")).intValue();
        String nextCursor = replyCount > replies.size() && !replies.isEmpty()
                ? replies.getFirst().id().toString() : null;
        return new PostCommentResponse(idOf(row), null, null, null, null,
                normalizeDateTime(row.get("created_at")), normalizeDateTime(row.get("updated_at")), row.get("deleted_at") != null,
                commentsCount, row.get("parent_comment_id") == null ? null : ((Number) row.get("parent_comment_id")).longValue(),
                replyCount, replies, nextCursor,
                row.get("deleted_at") == null && Boolean.TRUE.equals(row.get("blocked")));
    }

    private String commentAuthorProfileImageUrl(Map<String, Object> row) {
        if (row.get("profile_media_id") == null) {
            return null;
        }
        return "/api/v1/users/" + ((Number) row.get("user_id")).longValue() + "/profile-image";
    }

    private Set<Long> blockedAuthors(Long viewer) {
        return new HashSet<>(jdbcTemplate.queryForList(
                "SELECT blocked_user_id FROM user_blocks WHERE blocker_user_id = ?", Long.class, viewer));
    }

    private void maskBlockedComments(List<Map<String, Object>> rows, Set<Long> blocked) {
        for (Map<String, Object> row : rows) {
            row.put("blocked", blocked.contains(((Number) row.get("user_id")).longValue()));
        }
    }

    private int commentsCount(Long postId) {
        Integer count = jdbcTemplate.queryForObject("SELECT comments_count FROM posts WHERE id = ?", Integer.class, postId);
        return count == null ? 0 : count;
    }

    private int validateReplyLimit(int replyLimit) {
        if (replyLimit < 0 || replyLimit > 20) {
            throw new InvalidInputException("replyLimit must be between 0 and 20.", "INVALID_INPUT");
        }
        return replyLimit;
    }

    private Map<Long, List<PostCommentResponse>> loadReplies(List<Map<String, Object>> roots,
                                                              int replyLimit, int commentsCount, Set<Long> blocked) {
        if (roots.isEmpty() || replyLimit == 0) return Map.of();
        String placeholders = String.join(",", Collections.nCopies(roots.size(), "?"));
        List<Object> params = roots.stream().map(this::idOf).map(value -> (Object) value).collect(java.util.stream.Collectors.toCollection(ArrayList::new));
        params.add(replyLimit);
        String sql = """
                SELECT ranked.id, ranked.user_id, ranked.parent_comment_id, ranked.author_nickname,
                       ranked.profile_media_id, ranked.content, ranked.created_at, ranked.updated_at,
                       ranked.deleted_at, 0 AS reply_count
                FROM (
                    SELECT pc.id, pc.user_id, pc.parent_comment_id, u.nickname AS author_nickname,
                           u.profile_media_id, pc.content, pc.created_at, pc.updated_at, pc.deleted_at,
                           ROW_NUMBER() OVER (PARTITION BY pc.parent_comment_id ORDER BY pc.id DESC) AS rn
                    FROM post_comments pc
                    JOIN users u ON u.id = pc.user_id
                    WHERE pc.parent_comment_id IN (%s) AND pc.deleted_at IS NULL
                ) ranked
                WHERE ranked.rn <= ?
                ORDER BY ranked.parent_comment_id, ranked.id ASC
                """.formatted(placeholders);
        Map<Long, List<PostCommentResponse>> result = new HashMap<>();
        for (Map<String, Object> row : jdbcTemplate.queryForList(sql, params.toArray())) {
            maskBlockedComments(List.of(row), blocked);
            Long parentId = ((Number) row.get("parent_comment_id")).longValue();
            result.computeIfAbsent(parentId, ignored -> new ArrayList<>()).add(leafCommentResponse(row, commentsCount));
        }
        return result;
    }

    private Map<String, Object> requireComment(Long postId, Long commentId) {
        Map<String, Object> row = requireCommentAnyPost(commentId);
        if (!postId.equals(((Number) row.get("post_id")).longValue())) throw invalidCommentParent();
        return row;
    }

    private Map<String, Object> requireCommentAnyPost(Long commentId) {
        List<Map<String, Object>> rows = jdbcTemplate.queryForList("""
                SELECT pc.id, pc.post_id, pc.user_id, pc.parent_comment_id, u.nickname AS author_nickname,
                       u.profile_media_id, pc.content, pc.created_at, pc.updated_at, pc.deleted_at,
                       (SELECT COUNT(*) FROM post_comments child
                        WHERE child.parent_comment_id = pc.id AND child.deleted_at IS NULL) AS reply_count
                FROM post_comments pc
                JOIN users u ON u.id = pc.user_id
                WHERE pc.id = ?
                """, commentId);
        if (rows.isEmpty()) {
            throw new ApiException(HttpStatus.NOT_FOUND, "comment-not-found", "Comment Not Found",
                    "Comment not found.", "COMMENT_NOT_FOUND");
        }
        return rows.getFirst();
    }

    private ApiException commentNotFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "comment-not-found", "Comment Not Found",
                "Comment not found.", "COMMENT_NOT_FOUND");
    }

    private ApiException invalidCommentParent() {
        return new ApiException(HttpStatus.BAD_REQUEST, "invalid-comment-parent", "Invalid Comment Parent",
                "The parent comment must be a root comment on the same post.", "INVALID_COMMENT_PARENT");
    }

    private Long idOf(Map<String, Object> row) {
        return ((Number) row.get("id")).longValue();
    }

    private long parseCommentCursor(String cursor) {
        try {
            return Long.parseLong(cursor);
        } catch (NumberFormatException exception) {
            throw new InvalidInputException("Invalid comment cursor.", "INVALID_INPUT");
        }
    }

    private Instant normalizeDateTime(Object value) {
        return UtcTime.fromDatabase(value);
    }
}
