package com.formypet.community;

import com.formypet.auth.domain.User;
import com.formypet.auth.repository.UserRepository;
import com.formypet.community.dto.PostCreateRequest;
import com.formypet.community.dto.PostCommentCreateRequest;
import com.formypet.community.dto.PostCommentFeedResponse;
import com.formypet.community.dto.PostCommentResponse;
import com.formypet.community.dto.PostCommentUpdateRequest;
import com.formypet.community.dto.PostCommentReportRequest;
import com.formypet.community.dto.PostCommentReportResponse;
import com.formypet.community.dto.PostCommentReportReason;
import com.formypet.community.dto.PostFeedResponse;
import com.formypet.community.dto.PostLikeResponse;
import com.formypet.community.dto.PostResponse;
import com.formypet.community.dto.PostUpdateRequest;
import com.formypet.media.MediaService;
import com.formypet.media.dto.MediaResponse;
import com.formypet.notification.NotificationService;
import com.formypet.notification.NotificationType;
import com.formypet.common.exception.ApiException;
import com.formypet.common.exception.ForbiddenException;
import com.formypet.common.exception.InvalidInputException;
import lombok.RequiredArgsConstructor;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.jdbc.support.KeyHolder;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.sql.Date;
import java.sql.PreparedStatement;
import java.sql.Statement;
import java.sql.Timestamp;
import java.time.LocalDateTime;
import java.util.*;

@Service
@RequiredArgsConstructor
public class CommunityService {

    private static final Set<String> SORTS = Set.of("latest", "popular");
    private static final Set<String> CATEGORIES = Set.of(
            "CARE", "FOOD", "OUTING", "SHOW", "QUESTION",
            "FREE", "ADOPTION", "RESCUE", "NEWS", "EVENT"
    );

    private final JdbcTemplate jdbcTemplate;
    private final UserRepository userRepository;
    private final MediaService mediaService;
    private final NotificationService notificationService;

    @Transactional
    public PostResponse create(String email, PostCreateRequest request, List<MultipartFile> files) {
        User user = findUser(email);
        validateCreate(request, files);
        KeyHolder keyHolder = new GeneratedKeyHolder();
        LocalDateTime now = LocalDateTime.now();

        jdbcTemplate.update(connection -> {
            PreparedStatement ps = connection.prepareStatement("""
                    INSERT INTO posts (user_id, title, category, pet_species, content, likes_count, comments_count, created_at)
                    VALUES (?, ?, ?, ?, ?, 0, 0, ?)
                    """, Statement.RETURN_GENERATED_KEYS);
            ps.setLong(1, user.getId());
            ps.setString(2, request.title());
            ps.setString(3, normalizeCategory(request.category()));
            ps.setString(4, request.petSpecies());
            ps.setString(5, request.content());
            ps.setObject(6, now);
            return ps;
        }, keyHolder);

        Long postId = Objects.requireNonNull(keyHolder.getKey()).longValue();
        insertMedia(user, postId, files);
        insertPoll(postId, request.poll());
        return findPostResponse(postId, user.getId());
    }

    @Transactional(readOnly = true)
    public PostFeedResponse feed(String email, String keyword, String category, String sort, String cursor, int limit) {
        User user = findUser(email);
        String normalizedSort = SORTS.contains(sort) ? sort : "latest";
        String normalizedKeyword = normalizeKeyword(keyword);
        int pageSize = Math.max(1, Math.min(limit, 50));

        List<Object> params = new ArrayList<>();
        StringBuilder sql = new StringBuilder("""
                SELECT p.id, p.user_id, u.nickname AS author_nickname, p.title, p.category, p.pet_species, p.content,
                       p.likes_count, p.comments_count, p.created_at, u.profile_media_id,
                       EXISTS(SELECT 1 FROM post_likes pl WHERE pl.post_id = p.id AND pl.user_id = ?) AS liked
                FROM posts p
                JOIN users u ON u.id = p.user_id
                WHERE 1 = 1
                """);
        params.add(user.getId());
        if (category != null && !category.isBlank()) {
            sql.append(" AND p.category = ?");
            params.add(normalizeCategory(category));
        }
        if (normalizedKeyword != null) {
            String pattern = "%" + escapeLikeKeyword(normalizedKeyword) + "%";
            sql.append(" AND (p.title LIKE ? ESCAPE '!' OR p.content LIKE ? ESCAPE '!')");
            params.add(pattern);
            params.add(pattern);
        }
        appendCursor(sql, params, normalizedSort, cursor);
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
                .map(row -> toPostResponse(row, user.getId()))
                .toList();
        String nextCursor = hasNext ? cursorFor(items.getLast(), normalizedSort) : null;
        return PostFeedResponse.of(items, nextCursor);
    }

    @Transactional(readOnly = true)
    public PostResponse detail(String email, Long postId) {
        User user = findUser(email);
        ensurePostExists(postId);
        return findPostResponse(postId, user.getId());
    }

    @Transactional
    public PostResponse update(String email, Long postId, PostUpdateRequest request) {
        User user = findUser(email);
        ensurePostExists(postId);
        Long authorId = jdbcTemplate.queryForObject("SELECT user_id FROM posts WHERE id = ?", Long.class, postId);
        if (!user.getId().equals(authorId)) {
            throw new ForbiddenException("Forbidden post.", "POST_FORBIDDEN");
        }
        if (request.title() == null || request.title().isBlank() || request.title().length() > 30
                || request.category() == null || request.category().isBlank()
                || request.content() == null || request.content().isBlank()) {
            throw new IllegalArgumentException("Post title, category, and content are required; title must be 30 characters or fewer.");
        }
        jdbcTemplate.update("""
                UPDATE posts SET title = ?, category = ?, pet_species = ?, content = ? WHERE id = ?
                """, request.title().trim(), normalizeCategory(request.category()), request.petSpecies(),
                request.content().trim(), postId);
        return findPostResponse(postId, user.getId());
    }

    @Transactional
    public void delete(String email, Long postId) {
        User user = findUser(email);
        ensurePostExists(postId);
        Long authorId = jdbcTemplate.queryForObject("SELECT user_id FROM posts WHERE id = ?", Long.class, postId);
        if (!user.getId().equals(authorId)) {
            throw new ForbiddenException("Forbidden post.", "POST_FORBIDDEN");
        }
        jdbcTemplate.update("DELETE FROM posts WHERE id = ?", postId);
    }

    @Transactional(readOnly = true)
    public PostCommentFeedResponse comments(String email, Long postId, String cursor, int limit, int replyLimit) {
        findUser(email);
        ensurePostExists(postId);
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
        Map<Long, List<PostCommentResponse>> replies = loadReplies(rows, nestedPageSize, commentsCount);
        List<PostCommentResponse> items = rows.stream()
                .map(row -> rootCommentResponse(row, commentsCount, replies.getOrDefault(idOf(row), List.of())))
                .toList();
        String nextCursor = hasNext ? items.getLast().id().toString() : null;
        return PostCommentFeedResponse.of(items, nextCursor);
    }

    @Transactional(readOnly = true)
    public PostCommentResponse commentThread(String email, Long postId, Long commentId, int replyLimit) {
        findUser(email);
        ensurePostExists(postId);
        Map<String, Object> row = requireComment(postId, commentId);
        if (row.get("deleted_at") != null && ((Number) row.get("reply_count")).intValue() == 0) {
            throw commentNotFound();
        }
        if (row.get("parent_comment_id") != null) throw invalidCommentParent();
        int commentsCount = commentsCount(postId);
        List<PostCommentResponse> replies = loadReplies(List.of(row), validateReplyLimit(replyLimit), commentsCount)
                .getOrDefault(commentId, List.of());
        return rootCommentResponse(row, commentsCount, replies);
    }

    @Transactional(readOnly = true)
    public PostCommentFeedResponse replies(String email, Long postId, Long commentId, String cursor, int limit) {
        findUser(email);
        ensurePostExists(postId);
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
        List<PostCommentResponse> items = rows.stream().map(row -> leafCommentResponse(row, commentsCount)).toList();
        String nextCursor = hasNext && !items.isEmpty() ? items.getFirst().id().toString() : null;
        return PostCommentFeedResponse.of(items, nextCursor);
    }

    @Transactional
    public PostCommentResponse createComment(String email, Long postId, PostCommentCreateRequest request) {
        User user = findUser(email);
        ensurePostExists(postId);
        if (request == null) {
            throw new IllegalArgumentException("Comment content must be between 1 and 1000 characters.");
        }
        String content = request.content() == null ? "" : request.content().trim();
        if (content.isEmpty() || content.length() > 1000) {
            throw new IllegalArgumentException("Comment content must be between 1 and 1000 characters.");
        }
        Long parentCommentId = request.parentCommentId();
        if (parentCommentId != null) {
            Map<String, Object> parent = requireCommentAnyPost(parentCommentId);
            if (parent.get("deleted_at") != null) {
                throw commentNotFound();
            }
            if (!postId.equals(((Number) parent.get("post_id")).longValue())
                    || parent.get("parent_comment_id") != null) {
                throw invalidCommentParent();
            }
        }
        KeyHolder keyHolder = new GeneratedKeyHolder();
        jdbcTemplate.update(connection -> {
            PreparedStatement ps = connection.prepareStatement("""
                    INSERT INTO post_comments (post_id, user_id, parent_comment_id, content, created_at)
                    VALUES (?, ?, ?, ?, ?)
                    """, Statement.RETURN_GENERATED_KEYS);
            ps.setLong(1, postId);
            ps.setLong(2, user.getId());
            ps.setObject(3, parentCommentId);
            ps.setString(4, content);
            ps.setObject(5, LocalDateTime.now());
            return ps;
        }, keyHolder);
        jdbcTemplate.update("UPDATE posts SET comments_count = comments_count + 1 WHERE id = ?", postId);
        Long commentId = Objects.requireNonNull(keyHolder.getKey()).longValue();
        Long recipient = parentCommentId == null
                ? jdbcTemplate.queryForObject("SELECT user_id FROM posts WHERE id = ?", Long.class, postId)
                : ((Number) requireCommentAnyPost(parentCommentId).get("user_id")).longValue();
        notificationService.create(recipient, user.getId(), user.getNickname(),
                parentCommentId == null ? NotificationType.COMMENT : NotificationType.REPLY, postId, commentId);
        return findCommentResponse(commentId, commentsCount(postId));
    }

    @Transactional
    public PostCommentResponse updateComment(String email, Long postId, Long commentId,
                                             PostCommentUpdateRequest request) {
        User user = findUser(email);
        ensurePostExists(postId);
        Map<String, Object> comment = requireActiveComment(postId, commentId);
        if (!user.getId().equals(((Number) comment.get("user_id")).longValue())) {
            throw new ForbiddenException(
                    "Forbidden comment.", "COMMENT_FORBIDDEN");
        }
        String content = request.content().trim();
        LocalDateTime updatedAt = LocalDateTime.now();
        int updated = jdbcTemplate.update("""
                UPDATE post_comments
                SET content = ?, updated_at = ?
                WHERE id = ? AND post_id = ? AND deleted_at IS NULL
                """, content, updatedAt, commentId, postId);
        if (updated != 1) {
            throw commentNotFound();
        }
        return findCommentResponse(commentId, commentsCount(postId));
    }

    @Transactional
    public void deleteComment(String email, Long postId, Long commentId) {
        User user = findUser(email);
        ensurePostExists(postId);
        Map<String, Object> comment = requireActiveComment(postId, commentId);
        Long postAuthorId = jdbcTemplate.queryForObject(
                "SELECT user_id FROM posts WHERE id = ?", Long.class, postId);
        Long commentAuthorId = ((Number) comment.get("user_id")).longValue();
        if (!user.getId().equals(commentAuthorId) && !user.getId().equals(postAuthorId)) {
            throw new ForbiddenException(
                    "Forbidden comment.", "COMMENT_FORBIDDEN");
        }
        int updated = jdbcTemplate.update("""
                UPDATE post_comments SET deleted_at = ?
                WHERE id = ? AND post_id = ? AND deleted_at IS NULL
                """, LocalDateTime.now(), commentId, postId);
        if (updated != 1) throw commentNotFound();
        jdbcTemplate.update("""
                UPDATE posts SET comments_count = GREATEST(comments_count - 1, 0) WHERE id = ?
                """, postId);
    }

    @Transactional
    public PostCommentReportResponse reportComment(String email, Long postId, Long commentId,
                                                    PostCommentReportRequest request) {
        User reporter = findUser(email);
        ensurePostExists(postId);
        Map<String, Object> comment = requireActiveComment(postId, commentId);
        if (reporter.getId().equals(((Number) comment.get("user_id")).longValue())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "self-comment-report", "Invalid Comment Report",
                    "You cannot report your own comment.", "SELF_COMMENT_REPORT");
        }
        String detail = request.detail() == null ? null : request.detail().trim();
        if (request.reason() == PostCommentReportReason.OTHER && (detail == null || detail.isEmpty())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "comment-report-detail-required",
                    "Invalid Comment Report", "Detail is required for OTHER reports.",
                    "COMMENT_REPORT_DETAIL_REQUIRED");
        }
        LocalDateTime createdAt = LocalDateTime.now();
        KeyHolder keyHolder = new GeneratedKeyHolder();
        try {
            jdbcTemplate.update(connection -> {
                PreparedStatement ps = connection.prepareStatement("""
                        INSERT INTO post_comment_reports
                            (comment_id, reporter_user_id, reason, detail, content_snapshot, created_at)
                        VALUES (?, ?, ?, ?, ?, ?)
                        """, Statement.RETURN_GENERATED_KEYS);
                ps.setLong(1, commentId);
                ps.setLong(2, reporter.getId());
                ps.setString(3, request.reason().name());
                ps.setString(4, detail);
                ps.setString(5, (String) comment.get("content"));
                ps.setObject(6, createdAt);
                return ps;
            }, keyHolder);
        } catch (DuplicateKeyException exception) {
            throw new ApiException(HttpStatus.CONFLICT, "duplicate-comment-report", "Duplicate Comment Report",
                    "You have already reported this comment.", "DUPLICATE_COMMENT_REPORT");
        }
        Long reportId = Objects.requireNonNull(keyHolder.getKey()).longValue();
        return new PostCommentReportResponse(reportId, commentId, request.reason(), detail, createdAt);
    }

    @Transactional
    public PostLikeResponse toggleLike(String email, Long postId) {
        User user = findUser(email);
        ensurePostExists(postId);

        boolean alreadyLiked = countLike(user.getId(), postId) > 0;
        if (alreadyLiked) {
            jdbcTemplate.update("DELETE FROM post_likes WHERE user_id = ? AND post_id = ?", user.getId(), postId);
            jdbcTemplate.update("UPDATE posts SET likes_count = GREATEST(likes_count - 1, 0) WHERE id = ?", postId);
            return PostLikeResponse.of(postId, false, likesCount(postId));
        }

        jdbcTemplate.update("""
                INSERT INTO post_likes (user_id, post_id, created_at)
                VALUES (?, ?, ?)
                """, user.getId(), postId, LocalDateTime.now());
        jdbcTemplate.update("UPDATE posts SET likes_count = likes_count + 1 WHERE id = ?", postId);
        Long recipient = jdbcTemplate.queryForObject("SELECT user_id FROM posts WHERE id = ?", Long.class, postId);
        notificationService.create(recipient, user.getId(), user.getNickname(), NotificationType.POST_LIKE, postId, null);
        return PostLikeResponse.of(postId, true, likesCount(postId));
    }

    @Transactional
    public PostResponse vote(String email, Long postId, Long optionId) {
        User user = findUser(email);
        Long pollId = pollIdForPost(postId);
        ensureOptionBelongsToPoll(pollId, optionId);

        Long previousOptionId = previousVote(pollId, user.getId());
        if (previousOptionId == null) {
            jdbcTemplate.update("""
                    INSERT INTO post_poll_votes (poll_id, user_id, option_id, created_at, updated_at)
                    VALUES (?, ?, ?, ?, ?)
                    """, pollId, user.getId(), optionId, LocalDateTime.now(), LocalDateTime.now());
            jdbcTemplate.update("UPDATE post_poll_options SET votes_count = votes_count + 1 WHERE id = ?", optionId);
            Long recipient = jdbcTemplate.queryForObject("SELECT user_id FROM posts WHERE id = ?", Long.class, postId);
            notificationService.create(recipient, user.getId(), user.getNickname(), NotificationType.POLL_VOTE, postId, null);
        } else if (!previousOptionId.equals(optionId)) {
            jdbcTemplate.update("""
                    UPDATE post_poll_votes SET option_id = ?, updated_at = ? WHERE poll_id = ? AND user_id = ?
                    """, optionId, LocalDateTime.now(), pollId, user.getId());
            jdbcTemplate.update("UPDATE post_poll_options SET votes_count = GREATEST(votes_count - 1, 0) WHERE id = ?", previousOptionId);
            jdbcTemplate.update("UPDATE post_poll_options SET votes_count = votes_count + 1 WHERE id = ?", optionId);
        }

        return findPostResponse(postId, user.getId());
    }

    private void validateCreate(PostCreateRequest request, List<MultipartFile> files) {
        if (request.title() == null || request.title().isBlank()) {
            throw new IllegalArgumentException("Post title is required.");
        }
        if (request.category() == null || request.category().isBlank()) {
            throw new IllegalArgumentException("Post category is required.");
        }
        if (request.content() == null || request.content().isBlank()) {
            throw new IllegalArgumentException("Post content is required.");
        }
        if (request.title().length() > 30) {
            throw new IllegalArgumentException("Post title must be 30 characters or fewer.");
        }
        if (files.size() > 3) {
            throw new IllegalArgumentException("A post can include up to 3 images.");
        }
        if (request.poll() == null) {
            return;
        }
        List<String> options = request.poll().options();
        if (request.poll().question() == null || request.poll().question().isBlank()) {
            throw new IllegalArgumentException("Poll question is required.");
        }
        if (options == null || options.size() < 2 || options.size() > 5) {
            throw new IllegalArgumentException("Poll options must contain 2 to 5 items.");
        }
        if (options.stream().anyMatch(option -> option == null || option.isBlank())) {
            throw new IllegalArgumentException("Poll options must not be blank.");
        }
    }

    private void insertMedia(User user, Long postId, List<MultipartFile> files) {
        for (int i = 0; i < files.size(); i++) {
            MediaResponse media = mediaService.uploadCommunityMedia(user, files.get(i));
            jdbcTemplate.update("""
                    INSERT INTO post_media (post_id, media_id, sort_order)
                    VALUES (?, ?, ?)
                    """, postId, media.id(), i);
        }
    }

    private void insertPoll(Long postId, PostCreateRequest.PollCreateRequest poll) {
        if (poll == null) {
            return;
        }
        KeyHolder keyHolder = new GeneratedKeyHolder();
        jdbcTemplate.update(connection -> {
            PreparedStatement ps = connection.prepareStatement("""
                    INSERT INTO post_polls (post_id, question)
                    VALUES (?, ?)
                    """, Statement.RETURN_GENERATED_KEYS);
            ps.setLong(1, postId);
            ps.setString(2, poll.question());
            return ps;
        }, keyHolder);
        Long pollId = Objects.requireNonNull(keyHolder.getKey()).longValue();
        for (int i = 0; i < poll.options().size(); i++) {
            jdbcTemplate.update("""
                    INSERT INTO post_poll_options (poll_id, label, votes_count, sort_order)
                    VALUES (?, ?, 0, ?)
                    """, pollId, poll.options().get(i), i);
        }
    }

    private void appendCursor(StringBuilder sql, List<Object> params, String sort, String cursor) {
        if (cursor == null || cursor.isBlank()) {
            return;
        }
        if ("popular".equals(sort)) {
            String[] parts = cursor.split(":", 2);
            if (parts.length != 2) {
                throw new IllegalArgumentException("Invalid popular cursor.");
            }
            int likesCount = Integer.parseInt(parts[0]);
            long id = Long.parseLong(parts[1]);
            sql.append(" AND (p.likes_count < ? OR (p.likes_count = ? AND p.id < ?))");
            params.add(likesCount);
            params.add(likesCount);
            params.add(id);
            return;
        }
        sql.append(" AND p.id < ?");
        params.add(Long.parseLong(cursor));
    }

    private String cursorFor(PostResponse post, String sort) {
        if ("popular".equals(sort)) {
            return post.likesCount() + ":" + post.id();
        }
        return post.id().toString();
    }

    private PostResponse findPostResponse(Long postId, Long currentUserId) {
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

    private PostCommentResponse findCommentResponse(Long commentId, int commentsCount) {
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
        if (row.get("deleted_at") != null) {
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
        if (row.get("deleted_at") != null) {
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
                normalizeDateTime(row.get("created_at")), normalizeDateTime(row.get("updated_at")), true,
                commentsCount, null, replyCount, replies, nextCursor);
    }

    private String commentAuthorProfileImageUrl(Map<String, Object> row) {
        if (row.get("profile_media_id") == null) {
            return null;
        }
        return "/api/v1/users/" + ((Number) row.get("user_id")).longValue() + "/profile-image";
    }

    private PostResponse toPostResponse(Map<String, Object> row, Long currentUserId) {
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
                pollResponse(postId, currentUserId)
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

    private PostResponse.PollResponse pollResponse(Long postId, Long currentUserId) {
        var polls = jdbcTemplate.queryForList("""
                SELECT id, question FROM post_polls WHERE post_id = ?
                """, postId);
        if (polls.isEmpty()) {
            return null;
        }
        Map<String, Object> poll = polls.getFirst();
        Long pollId = ((Number) poll.get("id")).longValue();
        List<PostResponse.PollOptionResponse> options = jdbcTemplate.queryForList("""
                SELECT id, label, votes_count,
                       EXISTS(SELECT 1 FROM post_poll_votes ppv
                              WHERE ppv.poll_id = ? AND ppv.user_id = ? AND ppv.option_id = ppo.id) AS voted_by_me
                FROM post_poll_options ppo
                WHERE poll_id = ?
                ORDER BY sort_order ASC
                """, pollId, currentUserId, pollId).stream()
                .map(row -> new PostResponse.PollOptionResponse(
                        ((Number) row.get("id")).longValue(),
                        (String) row.get("label"),
                        ((Number) row.get("votes_count")).intValue(),
                        toBoolean(row.get("voted_by_me"))
                ))
                .toList();
        return new PostResponse.PollResponse(pollId, (String) poll.get("question"), options);
    }

    private void ensurePostExists(Long postId) {
        Integer count = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM posts WHERE id = ?", Integer.class, postId);
        if (count == null || count == 0) {
            throw new ApiException(HttpStatus.NOT_FOUND, "post-not-found", "Post Not Found", "Post not found.", "POST_NOT_FOUND");
        }
    }

    private int commentsCount(Long postId) {
        Integer count = jdbcTemplate.queryForObject("SELECT comments_count FROM posts WHERE id = ?", Integer.class, postId);
        return count == null ? 0 : count;
    }

    private int validateReplyLimit(int replyLimit) {
        if (replyLimit < 0 || replyLimit > 20) {
            throw new IllegalArgumentException("replyLimit must be between 0 and 20.");
        }
        return replyLimit;
    }

    private String normalizeKeyword(String keyword) {
        if (keyword == null) {
            return null;
        }
        String normalized = keyword.strip();
        if (normalized.isEmpty()) {
            return null;
        }
        int length = normalized.codePointCount(0, normalized.length());
        if (length < 2 || length > 20) {
            throw new IllegalArgumentException("Search keyword must be between 2 and 20 characters.");
        }
        return normalized;
    }

    private String escapeLikeKeyword(String keyword) {
        return keyword.replace("!", "!!")
                .replace("%", "!%")
                .replace("_", "!_");
    }

    private Map<Long, List<PostCommentResponse>> loadReplies(List<Map<String, Object>> roots,
                                                              int replyLimit, int commentsCount) {
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

    private Map<String, Object> requireActiveComment(Long postId, Long commentId) {
        Map<String, Object> row = requireCommentAnyPost(commentId);
        if (!postId.equals(((Number) row.get("post_id")).longValue()) || row.get("deleted_at") != null) {
            throw commentNotFound();
        }
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
            throw new IllegalArgumentException("Invalid comment cursor.");
        }
    }

    private Long pollIdForPost(Long postId) {
        var rows = jdbcTemplate.queryForList("SELECT id FROM post_polls WHERE post_id = ?", postId);
        if (rows.isEmpty()) {
            throw new IllegalArgumentException("Poll not found.");
        }
        return ((Number) rows.getFirst().get("id")).longValue();
    }

    private void ensureOptionBelongsToPoll(Long pollId, Long optionId) {
        Integer count = jdbcTemplate.queryForObject("""
                SELECT COUNT(*) FROM post_poll_options WHERE poll_id = ? AND id = ?
                """, Integer.class, pollId, optionId);
        if (count == null || count == 0) {
            throw new IllegalArgumentException("Poll option not found.");
        }
    }

    private Long previousVote(Long pollId, Long userId) {
        var rows = jdbcTemplate.queryForList("""
                SELECT option_id FROM post_poll_votes WHERE poll_id = ? AND user_id = ?
                """, pollId, userId);
        if (rows.isEmpty()) {
            return null;
        }
        return ((Number) rows.getFirst().get("option_id")).longValue();
    }

    private int countLike(Long userId, Long postId) {
        Integer count = jdbcTemplate.queryForObject("""
                SELECT COUNT(*) FROM post_likes WHERE user_id = ? AND post_id = ?
                """, Integer.class, userId, postId);
        return count == null ? 0 : count;
    }

    private int likesCount(Long postId) {
        Integer count = jdbcTemplate.queryForObject("SELECT likes_count FROM posts WHERE id = ?", Integer.class, postId);
        return count == null ? 0 : count;
    }

    private String normalizeCategory(String category) {
        String normalized = category == null ? "" : category.trim().toUpperCase(Locale.ROOT);
        if (!CATEGORIES.contains(normalized)) {
            throw InvalidInputException.invalidInput();
        }
        return normalized;
    }

    private User findUser(String email) {
        return userRepository.findByEmail(email)
                .orElseThrow(() -> new IllegalStateException("User not found."));
    }

    private LocalDateTime normalizeDateTime(Object value) {
        if (value == null) {
            return null;
        }
        if (value instanceof LocalDateTime localDateTime) {
            return localDateTime;
        }
        if (value instanceof Timestamp timestamp) {
            return timestamp.toLocalDateTime();
        }
        if (value instanceof Date date) {
            return date.toLocalDate().atStartOfDay();
        }
        return LocalDateTime.parse(value.toString());
    }

    private boolean toBoolean(Object value) {
        if (value instanceof Boolean bool) {
            return bool;
        }
        return ((Number) value).intValue() == 1;
    }
}
