package com.formypet.domain.community.entity;

import com.formypet.global.exception.InvalidInputException;
import com.formypet.global.time.UtcTime;
import org.junit.jupiter.api.Test;
import java.time.Instant;
import static org.assertj.core.api.Assertions.*;

class PostTest {
    @Test
    void creationPreservesTextButUpdateTrimsIt() {
        var post = Post.create(7L, " title ", " free ", "DOG", " body ");
        assertThat(post.getTitle()).isEqualTo(" title ");
        assertThat(post.getContent()).isEqualTo(" body ");
        assertThat(post.getCategory()).isEqualTo("FREE");
        post.update(" changed ", " food ", null, " updated ");
        assertThat(post.getTitle()).isEqualTo("changed");
        assertThat(post.getContent()).isEqualTo("updated");
        assertThat(post.getCategory()).isEqualTo("FOOD");
        assertThat(post.getPetSpecies()).isNull();
        assertThat(post.getUserId()).isEqualTo(7L);
    }

    @Test
    void titleLimitUsesExistingJavaLengthAndValidatesBeforeMutation() {
        var post = Post.create(7L, "a".repeat(30), "FREE", null, "body");
        assertThatThrownBy(() -> post.update("a".repeat(31), "FREE", null, "new"))
                .isInstanceOf(IllegalArgumentException.class);
        assertThat(post.getTitle()).isEqualTo("a".repeat(30));
        assertThat(post.getContent()).isEqualTo("body");
        assertThatThrownBy(() -> Post.create(7L, " ", "FREE", null, "body"))
                .isInstanceOf(IllegalArgumentException.class).hasMessage("Post title is required.");
        assertThatThrownBy(() -> Post.create(7L, "title", "FREE", null, " "))
                .isInstanceOf(IllegalArgumentException.class).hasMessage("Post content is required.");
    }

    @Test
    void categoryNormalizationRejectsUnknownValues() {
        assertThat(Post.normalizeCategory(" news ")).isEqualTo("NEWS");
        assertThatThrownBy(() -> Post.normalizeCategory("unknown"))
                .isInstanceOf(InvalidInputException.class);
        assertThatThrownBy(() -> Post.normalizeCategory(null))
                .isInstanceOf(InvalidInputException.class);
    }

    @Test
    void createdAtIsUtcAndSurvivesUpdates() {
        var before = UtcTime.toDatabase(Instant.now());
        var post = Post.create(7L, "title", "FREE", null, "body");
        var created = post.getCreatedAt();
        assertThat(created).isBetween(before, UtcTime.toDatabase(Instant.now()));
        assertThat(post.getLikesCount()).isZero();
        assertThat(post.getCommentsCount()).isZero();
        post.update("changed", "CARE", "CAT", "changed");
        assertThat(post.getCreatedAt()).isEqualTo(created);
    }
}
