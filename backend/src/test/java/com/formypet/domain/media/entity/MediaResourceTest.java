package com.formypet.domain.media.entity;

import com.formypet.global.time.UtcTime;
import java.time.Instant;
import org.junit.jupiter.api.Test;
import static org.assertj.core.api.Assertions.assertThat;

class MediaResourceTest {
    @Test
    void storedMetadataPreservesTheStorageResultAndOriginalName() {
        Instant before = Instant.now();
        var media = MediaResource.stored(1L, 2L, 3L, "1/pet-2/photo.png",
                " 원본 사진.PNG", "image/png", "png", 123L, "PRIVATE", "ACTIVITY_RECORD");
        Instant after = Instant.now();
        assertThat(media.getId()).isNull();
        assertThat(media.getUserId()).isEqualTo(1L);
        assertThat(media.getPetId()).isEqualTo(2L);
        assertThat(media.getRecordId()).isEqualTo(3L);
        assertThat(media.getStorageKey()).isEqualTo("1/pet-2/photo.png");
        assertThat(media.getOriginalName()).isEqualTo(" 원본 사진.PNG");
        assertThat(media.getContentType()).isEqualTo("image/png");
        assertThat(media.getExtension()).isEqualTo("png");
        assertThat(media.getFileSize()).isEqualTo(123L);
        assertThat(media.getStatus()).isEqualTo("STORED");
        assertThat(media.getCreatedAt()).isBetween(UtcTime.toDatabase(before), UtcTime.toDatabase(after));
        assertThat(media.isOwnedBy(1L)).isTrue();
        assertThat(media.isOwnedBy(9L)).isFalse();
        assertThat(media.isOwnedBy(null)).isFalse();
        assertThat(media.isPublic()).isFalse();
    }

    @Test
    void profileAndCommunityMetadataKeepNullableAttachmentIds() {
        var media = MediaResource.stored(1L, null, null, "1/community/photo.webp",
                "photo.webp", "image/webp", "webp", 17L, "PUBLIC", "GENERAL");
        assertThat(media.getPetId()).isNull();
        assertThat(media.getRecordId()).isNull();
        assertThat(media.isPublic()).isTrue();
        assertThat(media.getMediaKind()).isEqualTo("GENERAL");
    }

    @Test
    void defaultAttachmentKindKeepsRecordPrecedenceAndExplicitDraftKind() {
        assertThat(MediaResource.attachmentKind(null, null)).isEqualTo("GENERAL");
        assertThat(MediaResource.attachmentKind(2L, null)).isEqualTo("PET_PROFILE");
        assertThat(MediaResource.attachmentKind(2L, 3L)).isEqualTo("ACTIVITY_RECORD");
        var draft = MediaResource.stored(1L, 2L, null, "1/pet-log-2/draft.jpg",
                "draft.jpg", "image/jpeg", "jpg", 20L, "PRIVATE", "PET_LOG_DRAFT");
        assertThat(draft.getMediaKind()).isEqualTo("PET_LOG_DRAFT");
    }
}
