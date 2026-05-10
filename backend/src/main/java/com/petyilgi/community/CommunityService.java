package com.petyilgi.community;

import com.petyilgi.auth.domain.User;
import com.petyilgi.auth.repository.UserRepository;
import com.petyilgi.community.dto.PostCreateRequest;
import com.petyilgi.community.dto.PostFeedResponse;
import com.petyilgi.community.dto.PostLikeResponse;
import com.petyilgi.community.dto.PostResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.jdbc.support.KeyHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.sql.Date;
import java.sql.PreparedStatement;
import java.sql.Statement;
import java.sql.Timestamp;
import java.time.LocalDateTime;
import java.util.*;

@Service
@RequiredArgsConstructor
public class CommunityService {

    private final JdbcTemplate jdbcTemplate;
    private final UserRepository userRepository;

    @Transactional
    public PostResponse create(String email, PostCreateRequest request) {
        User user = findUser(email);
        KeyHolder keyHolder = new GeneratedKeyHolder();
        LocalDateTime now = LocalDateTime.now();

        jdbcTemplate.update(connection -> {
            PreparedStatement ps = connection.prepareStatement("""
                    INSERT INTO posts (user_id, pet_species, content, likes_count, created_at)
                    VALUES (?, ?, ?, 0, ?)
                    """, Statement.RETURN_GENERATED_KEYS);
            ps.setLong(1, user.getId());
            ps.setString(2, request.petSpecies());
            ps.setString(3, request.content());
            ps.setObject(4, now);
            return ps;
        }, keyHolder);

        Long postId = Objects.requireNonNull(keyHolder.getKey()).longValue();
        return findPostResponse(postId, user.getId());
    }

    @Transactional(readOnly = true)
    public PostFeedResponse feed(String email, Long cursor, int limit) {
        User user = findUser(email);
        int pageSize = Math.max(1, Math.min(limit, 50));

        List<Object> params = new ArrayList<>();
        StringBuilder sql = new StringBuilder("""
                SELECT p.id, p.user_id, u.nickname AS author_nickname, p.pet_species, p.content,
                       p.likes_count, p.created_at,
                       EXISTS(SELECT 1 FROM post_likes pl WHERE pl.post_id = p.id AND pl.user_id = ?) AS liked
                FROM posts p
                JOIN users u ON u.id = p.user_id
                WHERE 1 = 1
                """);
        params.add(user.getId());
        if (cursor != null) {
            sql.append(" AND p.id < ?");
            params.add(cursor);
        }
        sql.append(" ORDER BY p.id DESC LIMIT ?");
        params.add(pageSize);

        List<PostResponse> items = jdbcTemplate.queryForList(sql.toString(), params.toArray()).stream()
                .map(this::toPostResponse)
                .toList();
        Long nextCursor = items.size() == pageSize ? items.getLast().id() : null;
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

    private PostResponse findPostResponse(Long postId, Long currentUserId) {
        Map<String, Object> row = jdbcTemplate.queryForMap("""
                SELECT p.id, p.user_id, u.nickname AS author_nickname, p.pet_species, p.content,
                       p.likes_count, p.created_at,
                       EXISTS(SELECT 1 FROM post_likes pl WHERE pl.post_id = p.id AND pl.user_id = ?) AS liked
                FROM posts p
                JOIN users u ON u.id = p.user_id
                WHERE p.id = ?
                """, currentUserId, postId);
        return toPostResponse(row);
    }

    private void ensurePostExists(Long postId) {
        Integer count = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM posts WHERE id = ?", Integer.class, postId);
        if (count == null || count == 0) {
            throw new IllegalArgumentException("Post not found.");
        }
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

    private PostResponse toPostResponse(Map<String, Object> row) {
        return PostResponse.of(
                ((Number) row.get("id")).longValue(),
                ((Number) row.get("user_id")).longValue(),
                (String) row.get("author_nickname"),
                (String) row.get("pet_species"),
                (String) row.get("content"),
                ((Number) row.get("likes_count")).intValue(),
                toBoolean(row.get("liked")),
                normalizeDateTime(row.get("created_at"))
        );
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
