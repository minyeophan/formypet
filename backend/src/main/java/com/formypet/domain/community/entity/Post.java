package com.formypet.domain.community.entity;

import com.formypet.common.exception.InvalidInputException;
import com.formypet.common.time.UtcTime;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.JdbcType;
import org.hibernate.type.descriptor.jdbc.LocalDateTimeJdbcType;
import java.time.Instant;
import java.time.LocalDateTime;
import java.util.Locale;
import java.util.Set;

@Entity
@Table(name = "posts")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Post {
    private static final Set<String> CATEGORIES = Set.of(
            "CARE", "FOOD", "OUTING", "SHOW", "QUESTION", "FREE", "ADOPTION", "RESCUE", "NEWS", "EVENT");

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(name = "user_id", nullable = false, updatable = false)
    private Long userId;
    @Column(nullable = false, length = 120)
    private String title;
    @Column(nullable = false, length = 30)
    private String category;
    @Column(name = "pet_species", length = 30)
    private String petSpecies;
    @Column(nullable = false, columnDefinition = "TEXT")
    private String content;
    // Counter changes use atomic repository operations, never a stale entity snapshot.
    @Column(name = "likes_count", nullable = false, updatable = false)
    private int likesCount;
    @Column(name = "comments_count", nullable = false, updatable = false)
    private int commentsCount;
    @JdbcType(LocalDateTimeJdbcType.class)
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    public static Post create(Long userId, String title, String category, String petSpecies, String content) {
        validateCreate(title, category, content);
        var post = new Post();
        post.userId = userId;
        post.title = title;
        post.category = normalizeCategory(category);
        post.petSpecies = petSpecies;
        post.content = content;
        post.createdAt = UtcTime.toDatabase(Instant.now());
        return post;
    }

    public static void validateCreate(String title, String category, String content) {
        if (title == null || title.isBlank()) throw new IllegalArgumentException("Post title is required.");
        if (category == null || category.isBlank()) throw new IllegalArgumentException("Post category is required.");
        if (content == null || content.isBlank()) throw new IllegalArgumentException("Post content is required.");
        if (title.length() > 30) throw new IllegalArgumentException("Post title must be 30 characters or fewer.");
    }

    public static void validateUpdate(String title, String category, String content) {
        if (title == null || title.isBlank() || title.length() > 30
                || category == null || category.isBlank() || content == null || content.isBlank()) {
            throw new IllegalArgumentException("Post title, category, and content are required; title must be 30 characters or fewer.");
        }
    }

    public void update(String title, String category, String petSpecies, String content) {
        validateUpdate(title, category, content);
        String normalizedCategory = normalizeCategory(category);
        this.title = title.trim();
        this.category = normalizedCategory;
        this.petSpecies = petSpecies;
        this.content = content.trim();
    }

    public static String normalizeCategory(String category) {
        String normalized = category == null ? "" : category.trim().toUpperCase(Locale.ROOT);
        if (!CATEGORIES.contains(normalized)) throw InvalidInputException.invalidInput();
        return normalized;
    }
}
