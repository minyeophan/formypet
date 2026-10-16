package com.formypet.domain.community.entity;

import com.formypet.global.time.UtcTime;
import org.junit.jupiter.api.Test;
import java.time.Instant;
import static org.assertj.core.api.Assertions.*;

class PostCommentTest {
    @Test
    void creationTrimsContentAndKeepsParentAndUtcTimestamp() {
        var before = UtcTime.toDatabase(Instant.now());
        var comment = PostComment.create(3L, 7L, 12L, " comment ");
        assertThat(comment.getPostId()).isEqualTo(3L);
        assertThat(comment.getUserId()).isEqualTo(7L);
        assertThat(comment.getParentCommentId()).isEqualTo(12L);
        assertThat(comment.getContent()).isEqualTo("comment");
        assertThat(comment.getCreatedAt()).isBetween(before, UtcTime.toDatabase(Instant.now()));
        assertThat(comment.getUpdatedAt()).isNull();
        assertThat(comment.getDeletedAt()).isNull();
    }

    @Test
    void rejectsBlankNullAndOverlongContent() {
        for (String invalid : new String[]{null, "  ", "a".repeat(1001)}) {
            assertThatThrownBy(() -> PostComment.create(3L, 7L, null, invalid))
                    .isInstanceOf(IllegalArgumentException.class)
                    .hasMessage("Comment content must be between 1 and 1000 characters.");
        }
        assertThat(PostComment.create(3L, 7L, null, "a".repeat(1000)).getContent()).hasSize(1000);
    }

    @Test
    void deletionPermissionIncludesCommentAndPostAuthorOnly() {
        var comment = PostComment.create(3L, 7L, null, "body");
        assertThat(comment.canBeDeletedBy(7L, 9L)).isTrue();
        assertThat(comment.canBeDeletedBy(9L, 9L)).isTrue();
        assertThat(comment.canBeDeletedBy(10L, 9L)).isFalse();
    }
}
