package com.petyilgi.community;

import com.petyilgi.auth.domain.User;
import com.petyilgi.auth.repository.UserRepository;
import com.petyilgi.community.dto.PostCreateRequest;
import com.petyilgi.community.dto.PostFeedResponse;
import com.petyilgi.community.dto.PostLikeResponse;
import com.petyilgi.community.dto.PostResponse;
import com.petyilgi.media.MediaService;
import com.petyilgi.media.dto.MediaResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.jdbc.support.KeyHolder;
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

    private final JdbcTemplate jdbcTemplate;
    private final UserRepository userRepository;
    private final MediaService mediaService;

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
    public PostFeedResponse feed(String email, String category, String sort, String cursor, int limit) {
        User user = findUser(email);
        String normalizedSort = SORTS.contains(sort) ? sort : "latest";
        int pageSize = Math.max(1, Math.min(limit, 50));

        List<Object> params = new ArrayList<>();
        StringBuilder sql = new StringBuilder("""
                SELECT p.id, p.user_id, u.nickname AS author_nickname, p.title, p.category, p.pet_species, p.content,
                       p.likes_count, p.comments_count, p.created_at,
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
        appendCursor(sql, params, normalizedSort, cursor);
        if ("popular".equals(normalizedSort)) {
            sql.append(" ORDER BY p.likes_count DESC, p.id DESC LIMIT ?");
        } else {
            sql.append(" ORDER BY p.id DESC LIMIT ?");
        }
        params.add(pageSize);

        List<PostResponse> items = jdbcTemplate.queryForList(sql.toString(), params.toArray()).stream()
                .map(row -> toPostResponse(row, user.getId()))
                .toList();
        String nextCursor = items.size() == pageSize ? cursorFor(items.getLast(), normalizedSort) : null;
        return PostFeedResponse.of(items, nextCursor);
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
        if (request.title().length() > 120) {
            throw new IllegalArgumentException("Post title must be 120 characters or fewer.");
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
                       p.likes_count, p.comments_count, p.created_at,
                       EXISTS(SELECT 1 FROM post_likes pl WHERE pl.post_id = p.id AND pl.user_id = ?) AS liked
                FROM posts p
                JOIN users u ON u.id = p.user_id
                WHERE p.id = ?
                """, currentUserId, postId);
        return toPostResponse(row, currentUserId);
    }

    private PostResponse toPostResponse(Map<String, Object> row, Long currentUserId) {
        Long postId = ((Number) row.get("id")).longValue();
        return PostResponse.of(
                postId,
                ((Number) row.get("user_id")).longValue(),
                (String) row.get("author_nickname"),
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
            throw new IllegalArgumentException("Post not found.");
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
        return category.toUpperCase(Locale.ROOT);
    }

    private User findUser(String email) {
        return userRepository.findByEmail(email)
                .orElseThrow(() -> new IllegalStateException("User not found."));
    }

    private LocalDateTime normalizeDateTime(Object value) {
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
