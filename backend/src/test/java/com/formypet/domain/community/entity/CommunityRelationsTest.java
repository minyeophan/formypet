package com.formypet.domain.community.entity;

import com.formypet.global.time.UtcTime;
import org.junit.jupiter.api.Test;
import java.time.Instant;
import java.util.List;
import static org.assertj.core.api.Assertions.*;

class CommunityRelationsTest {
    @Test
    void pollPreservesQuestionAndRequiresTwoToFiveNonblankOptions() {
        PostPoll.validate(" question ", List.of(" one ", "two"));
        assertThat(PostPoll.create(3L, " question ").getQuestion()).isEqualTo(" question ");
        assertThatThrownBy(() -> PostPoll.validate(" ", List.of("one", "two")))
                .isInstanceOf(IllegalArgumentException.class).hasMessage("Poll question is required.");
        for (int size : new int[]{0, 1, 6}) {
            assertThatThrownBy(() -> PostPoll.validate("question", java.util.Collections.nCopies(size, "one")))
                    .isInstanceOf(IllegalArgumentException.class).hasMessage("Poll options must contain 2 to 5 items.");
        }
        assertThatThrownBy(() -> PostPoll.validate("question", List.of("one", " ")))
                .isInstanceOf(IllegalArgumentException.class).hasMessage("Poll options must not be blank.");
    }

    @Test
    void optionAndMediaPreserveOrderAndScalarReferences() {
        var option = PostPollOption.create(3L, " option ", 4);
        assertThat(option.getPollId()).isEqualTo(3L);
        assertThat(option.getLabel()).isEqualTo(" option ");
        assertThat(option.getSortOrder()).isEqualTo(4);
        assertThat(option.getVotesCount()).isZero();
        var media = PostMedia.create(7L, 9L, 2);
        assertThat(media.getPostId()).isEqualTo(7L);
        assertThat(media.getMediaId()).isEqualTo(9L);
        assertThat(media.getSortOrder()).isEqualTo(2);
    }

    @Test
    void voteChangesOnlyForAnotherOptionAndUsesUtc() {
        var before = UtcTime.toDatabase(Instant.now());
        var vote = PostPollVote.create(3L, 7L, 11L);
        var created = vote.getCreatedAt();
        var updated = vote.getUpdatedAt();
        assertThat(created).isBetween(before, UtcTime.toDatabase(Instant.now()));
        assertThat(vote.changeOption(11L)).isFalse();
        assertThat(vote.getUpdatedAt()).isEqualTo(updated);
        assertThat(vote.changeOption(12L)).isTrue();
        assertThat(vote.getOptionId()).isEqualTo(12L);
        assertThat(vote.getCreatedAt()).isEqualTo(created);
        assertThat(vote.getUpdatedAt()).isAfterOrEqualTo(updated);
        assertThat(PostLike.create(7L, 9L).getCreatedAt()).isBetween(before, UtcTime.toDatabase(Instant.now()));
    }
}
