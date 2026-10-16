package com.formypet.domain.media;

import com.formypet.domain.media.entity.MediaResource;
import com.formypet.domain.media.repository.MediaResourceRepository;
import com.formypet.support.IntegrationTestSupport;
import jakarta.persistence.EntityManager;
import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.within;

@Transactional
class MediaResourceRepositoryIntegrationTest extends IntegrationTestSupport {
    @Autowired MediaResourceRepository media;
    @Autowired JdbcTemplate jdbc;
    @Autowired EntityManager entities;

    @Test
    void saveAndFlushWritesMetadataAndRoundTripsWithoutTimezoneConversion() {
        long owner = user();
        var stored = media.saveAndFlush(MediaResource.stored(owner, null, null,
                "test/" + UUID.randomUUID() + ".png", "한글 이름.PNG", "image/png", "png",
                123L, "PUBLIC", "GENERAL"));
        assertThat(stored.getId()).isPositive();
        LocalDateTime databaseTime = jdbc.queryForObject("SELECT created_at FROM media_resources WHERE id=?",
                LocalDateTime.class, stored.getId());
        assertThat(databaseTime).isCloseTo(stored.getCreatedAt(), within(1, ChronoUnit.MICROS));
        entities.clear();
        var loaded = media.findById(stored.getId()).orElseThrow();
        assertThat(loaded.getOriginalName()).isEqualTo("한글 이름.PNG");
        assertThat(loaded.getFileSize()).isEqualTo(123L);
        assertThat(loaded.getStatus()).isEqualTo("STORED");
        assertThat(loaded.getCreatedAt()).isEqualTo(databaseTime);
        assertThat(loaded.isPublic()).isTrue();
    }

    @Test
    void existingRowsKeepTheirUtcWallClockAndNullableAttachmentIds() {
        long owner = user();
        String key = "legacy/" + UUID.randomUUID() + ".webp";
        LocalDateTime utc = LocalDateTime.parse("2026-01-02T03:04:05.123456");
        jdbc.update("""
                INSERT INTO media_resources(user_id,storage_key,original_name,content_type,extension,
                    file_size,status,visibility,created_at,media_kind)
                VALUES (?,?,?,'image/webp','webp',99,'STORED','PRIVATE',?,'GENERAL')
                """, owner, key, "legacy.webp", utc);
        Long id = jdbc.queryForObject("SELECT id FROM media_resources WHERE storage_key=?", Long.class, key);
        var loaded = media.findById(id).orElseThrow();
        assertThat(loaded.getCreatedAt()).isEqualTo(utc);
        assertThat(loaded.getPetId()).isNull();
        assertThat(loaded.getRecordId()).isNull();
        assertThat(loaded.getMediaKind()).isEqualTo("GENERAL");
        assertThat(loaded.isPublic()).isFalse();
    }

    @Test
    void conditionalDeleteRejectsOtherOwnersAndReportsOnlyTheFirstDeletion() {
        long owner = user();
        var stored = media.saveAndFlush(MediaResource.stored(owner, null, null,
                "delete/" + UUID.randomUUID() + ".png", "photo.png", "image/png", "png",
                20L, "PRIVATE", "GENERAL"));
        assertThat(media.deleteOwned(stored.getId(), owner + 1)).isZero();
        assertThat(media.deleteOwned(stored.getId(), owner)).isEqualTo(1);
        assertThat(media.deleteOwned(stored.getId(), owner)).isZero();
        entities.clear();
        assertThat(media.findById(stored.getId())).isEmpty();
    }

    @Test
    void ownedProfileAndPetLogQueriesKeepTheirOriginalSelectionRules() {
        long owner = user();
        var stored = media.saveAndFlush(MediaResource.stored(owner, null, null,
                "selection/" + UUID.randomUUID() + ".png", "profile.png", "image/png", "png",
                20L, "PRIVATE", "GENERAL"));
        assertThat(media.profileFile(stored.getId(), owner)).isPresent();
        assertThat(media.ownedFile(stored.getId(), owner + 1)).isEmpty();
        assertThat(media.petLogLocation(stored.getId(), owner)).isEmpty();
        jdbc.update("UPDATE media_resources SET media_kind='PET_LOG_DRAFT' WHERE id=?", stored.getId());
        // Read the database kind even when an older entity is already managed in this transaction.
        assertThat(media.petLogLocation(stored.getId(), owner)).isPresent();
        assertThat(media.petLogLocation(stored.getId(), owner + 1)).isEmpty();
        assertThat(media.profileFile(stored.getId(), owner).orElseThrow().fileSize()).isEqualTo(20);
    }

    @Test
    void metadataAndProjectionReadsUseOneStatementWithoutLoadingRelatedEntities() {
        long owner = user();
        var stored = media.saveAndFlush(MediaResource.stored(owner, null, null,
                "query-cost/" + UUID.randomUUID() + ".png", "photo.png", "image/png", "png",
                20L, "PRIVATE", "GENERAL"));
        entities.clear();
        var stats = entities.getEntityManagerFactory().unwrap(org.hibernate.SessionFactory.class).getStatistics();
        boolean enabled = stats.isStatisticsEnabled();
        stats.setStatisticsEnabled(true);
        try {
            stats.clear();
            var loaded = media.findById(stored.getId()).orElseThrow();
            assertThat(loaded.getUserId()).isEqualTo(owner);
            assertThat(loaded.getStorageKey()).isEqualTo(stored.getStorageKey());
            assertThat(stats.getPrepareStatementCount()).isEqualTo(1);
            assertThat(stats.getEntityLoadCount()).isEqualTo(1);
            stats.clear();
            assertThat(media.profileFile(stored.getId(), owner)).isPresent();
            assertThat(stats.getPrepareStatementCount()).isEqualTo(1);
            assertThat(stats.getEntityLoadCount()).isZero();
        } finally {
            stats.setStatisticsEnabled(enabled);
        }
    }

    private long user() {
        String email = UUID.randomUUID() + "@media-jpa.invalid";
        jdbc.update("INSERT INTO users(email,password_hash,nickname) VALUES (?,'unused','media mapping')", email);
        return jdbc.queryForObject("SELECT id FROM users WHERE email=?", Long.class, email);
    }
}
