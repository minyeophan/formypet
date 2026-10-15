package com.formypet.domain.media;

import com.formypet.domain.media.entity.MediaResource;
import com.formypet.domain.media.repository.MediaResourceRepository;
import com.formypet.domain.media.repository.jdbc.MediaAttachmentRepository;
import com.formypet.support.IntegrationTestSupport;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import static org.assertj.core.api.Assertions.assertThat;

@Transactional
class MediaAttachmentRepositoryIntegrationTest extends IntegrationTestSupport {
    @Autowired MediaAttachmentRepository attachments;
    @Autowired MediaResourceRepository media;
    @Autowired JdbcTemplate jdbc;

    @Test
    void expiredDraftCleanupOnlySelectsOldDraftsAndUsesTypedRows() {
        String email = UUID.randomUUID() + "@attachment.invalid";
        jdbc.update("INSERT INTO users(email,password_hash,nickname) VALUES (?,'unused','attachment')", email);
        Long owner = jdbc.queryForObject("SELECT id FROM users WHERE email=?", Long.class, email);
        var old = store(owner, "PET_LOG_DRAFT");
        var fresh = store(owner, "PET_LOG_DRAFT");
        var published = store(owner, "PET_LOG");
        jdbc.update("UPDATE media_resources SET created_at=UTC_TIMESTAMP(6)-INTERVAL 25 HOUR WHERE id IN (?,?)",
                old.getId(), published.getId());
        assertThat(attachments.expiredDraftOwners()).contains(owner);
        var rows = attachments.lockExpiredDrafts(owner);
        assertThat(rows).hasSize(1);
        assertThat(rows.getFirst().id()).isEqualTo(old.getId());
        assertThat(rows.getFirst().storageKey()).isEqualTo(old.getStorageKey());
        assertThat(rows.getFirst().fileSize()).isEqualTo(15);
        assertThat(attachments.deleteExpiredDrafts(owner)).isEqualTo(1);
        assertThat(attachments.lockExpiredDrafts(owner)).isEmpty();
        assertThat(attachments.lockPetLogIds(owner, java.util.List.of(fresh.getId(), published.getId())))
                .extracting(row -> row.id()).containsExactly(published.getId());
    }

    private MediaResource store(Long owner, String kind) {
        return media.saveAndFlush(MediaResource.stored(owner, null, null,
                "attachment/" + UUID.randomUUID() + ".png", "photo.png", "image/png", "png",
                15L, "PRIVATE", kind));
    }
}
