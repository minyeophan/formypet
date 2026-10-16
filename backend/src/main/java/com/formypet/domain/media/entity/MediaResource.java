package com.formypet.domain.media.entity;

import com.formypet.global.time.UtcTime;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.time.LocalDateTime;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.JdbcType;
import org.hibernate.type.descriptor.jdbc.LocalDateTimeJdbcType;

@Entity
@Table(name = "media_resources")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class MediaResource {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(name = "user_id", nullable = false, updatable = false)
    private Long userId;
    @Column(name = "pet_id", updatable = false)
    private Long petId;
    @Column(name = "record_id", updatable = false)
    private Long recordId;
    @Column(name = "storage_key", nullable = false, unique = true, length = 500, updatable = false)
    private String storageKey;
    @Column(name = "original_name", nullable = false, length = 255, updatable = false)
    private String originalName;
    @Column(name = "content_type", nullable = false, length = 100, updatable = false)
    private String contentType;
    @Column(nullable = false, length = 10, updatable = false)
    private String extension;
    @Column(name = "file_size", nullable = false, updatable = false)
    private long fileSize;
    @Column(nullable = false, columnDefinition = "enum('STORED')", updatable = false)
    private String status;
    @Column(nullable = false, length = 20, updatable = false)
    private String visibility;
    @Column(name = "media_kind", nullable = false, length = 30)
    private String mediaKind;
    @JdbcType(LocalDateTimeJdbcType.class)
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    public static MediaResource stored(Long userId, Long petId, Long recordId, String storageKey,
                                       String originalName, String contentType, String extension,
                                       long fileSize, String visibility, String mediaKind) {
        var media = new MediaResource();
        media.userId = userId;
        media.petId = petId;
        media.recordId = recordId;
        media.storageKey = storageKey;
        media.originalName = originalName;
        media.contentType = contentType;
        media.extension = extension;
        media.fileSize = fileSize;
        media.status = "STORED";
        media.visibility = visibility;
        media.mediaKind = mediaKind;
        media.createdAt = UtcTime.toDatabase(Instant.now());
        return media;
    }

    public static String attachmentKind(Long petId, Long recordId) {
        return recordId != null ? "ACTIVITY_RECORD" : petId != null ? "PET_PROFILE" : "GENERAL";
    }

    public boolean isOwnedBy(Long actorId) {
        return userId.equals(actorId);
    }

    public boolean isPublic() {
        return "PUBLIC".equals(visibility);
    }
}
