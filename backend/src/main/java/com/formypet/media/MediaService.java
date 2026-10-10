package com.formypet.media;

import com.formypet.auth.domain.User;
import com.formypet.auth.repository.UserRepository;
import com.formypet.common.exception.ApiException;
import com.formypet.common.ratelimit.RequestRateLimiter;
import com.formypet.common.ratelimit.RequestRateLimitProperties;
import com.formypet.media.dto.MediaResponse;
import com.formypet.media.storage.LoadedMedia;
import com.formypet.media.storage.MediaStorage;
import com.formypet.media.storage.StoredMedia;
import com.formypet.pet.domain.Pet;
import com.formypet.pet.repository.PetRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.jdbc.support.KeyHolder;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.sql.PreparedStatement;
import java.sql.Statement;
import java.time.Instant;
import com.formypet.common.time.UtcTime;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;
import java.util.Set;

@Service
@RequiredArgsConstructor
@lombok.extern.slf4j.Slf4j
public class MediaService {

    private static final long MAX_FILE_SIZE = 5L * 1024 * 1024;
    private static final Set<String> ALLOWED_EXTENSIONS = Set.of("jpg", "jpeg", "png", "webp");

    private final UserRepository userRepository;
    private final PetRepository petRepository;
    private final JdbcTemplate jdbcTemplate;
    private final MediaStorage mediaStorage;
    private final OrphanMediaCleanup orphanCleanup;
    private final MediaStorageAttempts storageAttempts;
    private final RequestRateLimiter requestRateLimiter;
    private final RequestRateLimitProperties requestLimits;

    @Transactional
    public MediaResponse uploadPetMedia(Long actorId, Long petId, MultipartFile file) {
        User user = findUser(actorId);
        Pet pet = findOwnedPet(user, petId);
        return storeAndInsert(user.getId(), pet.getId(), null, "PRIVATE", "pet-" + pet.getId(), file, false);
    }

    @Transactional
    public MediaResponse uploadRecordMedia(Long actorId, Long petId, Long recordId, MultipartFile file) {
        User user = findUser(actorId);
        Pet pet = findOwnedPet(user, petId);
        ensureRecordBelongsToPet(pet.getId(), recordId);
        return storeAndInsert(user.getId(), pet.getId(), recordId, "PRIVATE", "pet-" + pet.getId(), file, false);
    }

    @Transactional
    public MediaResponse uploadUserProfileMedia(Long actorId, MultipartFile file) {
        return uploadUserProfileMedia(actorId, file, null);
    }

    @Transactional
    public MediaResponse uploadUserProfileMedia(Long actorId, MultipartFile file, Long replacedMediaId) {
        User user = findUser(actorId);
        validateFile(file);
        long replacedBytes = profileMediaBytes(user.getId(), replacedMediaId);
        int itemDelta = replacedBytes < 0 ? 1 : 0;
        reserveQuota(user.getId(), file.getSize() - Math.max(replacedBytes, 0), itemDelta);
        return storeAndInsert(user.getId(), null, null, "PRIVATE", "profile", file, true);
    }

    @Transactional
    public void deleteUserProfileMedia(Long userId, Long mediaId) {
        deleteProfileMedia(userId, mediaId, true);
    }

    @Transactional
    public void deleteReplacedUserProfileMedia(Long userId, Long mediaId) {
        deleteProfileMedia(userId, mediaId, false);
    }

    private void deleteProfileMedia(Long userId, Long mediaId, boolean updateQuota) {
        var rows = jdbcTemplate.queryForList("""
                SELECT storage_key, file_size
                FROM media_resources
                WHERE id = ? AND user_id = ? AND pet_id IS NULL AND record_id IS NULL
                """, mediaId, userId);
        if (rows.isEmpty()) {
            return;
        }

        String storageKey = (String) rows.getFirst().get("storage_key");
        jdbcTemplate.update("INSERT IGNORE INTO media_cleanup_queue(storage_key) VALUES (?)", storageKey);
        int deleted = jdbcTemplate.update("DELETE FROM media_resources WHERE id = ? AND user_id = ?", mediaId, userId);
        if (deleted == 1 && updateQuota) decrementQuota(userId, ((Number) rows.getFirst().get("file_size")).longValue(), 1);
    }

    @Transactional
    public java.util.List<MediaResponse> uploadCommunityMedia(User user, java.util.List<MultipartFile> files) {
        files.forEach(this::validateFile);
        if (files.isEmpty()) return java.util.List.of();
        long totalBytes = files.stream().mapToLong(MultipartFile::getSize).sum();
        reserveQuota(user.getId(), totalBytes, files.size());
        return files.stream().map(file -> storeAndInsert(user.getId(), null, null, "PUBLIC", "community",
                file, true)).toList();
    }

    @Transactional
    public void deleteCommunityMedia(Long userId, Long mediaId) {
        deleteOwnedMedia(userId, mediaId);
    }

    @Transactional
    public void deleteRecordMedia(Long userId, Long recordId) {
        // Serialize record-media cleanup with quota reservations and other media deletes for this user.
        var owners = jdbcTemplate.queryForList("SELECT id FROM users WHERE id=? FOR UPDATE", Long.class, userId);
        if (owners.isEmpty()) return;
        var rows = jdbcTemplate.queryForList("""
                SELECT storage_key, file_size FROM media_resources
                WHERE user_id=? AND record_id=? FOR UPDATE
                """, userId, recordId);
        if (rows.isEmpty()) return;
        int deleted = jdbcTemplate.update("DELETE FROM media_resources WHERE user_id=? AND record_id=?", userId, recordId);
        if (deleted != rows.size()) {
            throw new IllegalStateException("Record media changed during deletion.");
        }
        for (var row : rows) {
            jdbcTemplate.update("INSERT IGNORE INTO media_cleanup_queue(storage_key) VALUES (?)", row.get("storage_key"));
        }
        long bytes = rows.stream().mapToLong(row -> ((Number) row.get("file_size")).longValue()).sum();
        decrementQuota(userId, bytes, deleted);
    }

    @Transactional(readOnly = true)
    public LoadedMedia load(Long actorId, Long mediaId) {
        User user = findUser(actorId);
        Map<String, Object> media = findMedia(mediaId);
        Long ownerId = ((Number) media.get("user_id")).longValue();
        if (!ownerId.equals(user.getId())) {
            throw new AccessDeniedException("Cannot access media owned by another user.");
        }
        try {
            return mediaStorage.load((String) media.get("storage_key"), (String) media.get("content_type"));
        } catch (IOException e) {
            throw new IllegalStateException("Failed to read media file.", e);
        }
    }

    @Transactional(readOnly = true)
    public LoadedMedia loadPublic(Long mediaId) {
        Map<String, Object> media = findMedia(mediaId);
        if (!"PUBLIC".equals(media.get("visibility"))) {
            throw new AccessDeniedException("Cannot access private media from public endpoint.");
        }
        try {
            return mediaStorage.load((String) media.get("storage_key"), (String) media.get("content_type"));
        } catch (IOException e) {
            throw new IllegalStateException("Failed to read media file.", e);
        }
    }

    @Transactional(readOnly = true)
    public LoadedMedia loadUserProfileImage(Long userId) {
        var rows = jdbcTemplate.queryForList("""
                SELECT mr.storage_key, mr.content_type
                FROM users u
                JOIN media_resources mr ON mr.id = u.profile_media_id
                WHERE u.id = ?
                """, userId);
        if (rows.isEmpty()) {
            throw new ApiException(
                    HttpStatus.NOT_FOUND,
                    "profile-image-not-found",
                    "Profile Image Not Found",
                    "Profile image not found.",
                    "PROFILE_IMAGE_NOT_FOUND"
            );
        }
        Map<String, Object> media = rows.getFirst();
        try {
            return mediaStorage.load((String) media.get("storage_key"), (String) media.get("content_type"));
        } catch (IOException e) {
            throw new IllegalStateException("Failed to read media file.", e);
        }
    }

    private MediaResponse storeAndInsert(Long userId, Long petId, Long recordId, String visibility,
                                         String folderName, MultipartFile file, boolean quotaReserved) {
        validateFile(file);
        if (!quotaReserved) reserveQuota(userId, file.getSize(), 1);
        String extension = extension(file.getOriginalFilename());
        String storageKey = MediaStorage.allocateKey(userId, folderName, extension);
        storageAttempts.begin(storageKey);
        jdbcTemplate.queryForObject("SELECT storage_key FROM media_storage_attempts WHERE storage_key=? FOR UPDATE",
                String.class, storageKey);
        StoredMedia stored;
        try {
            stored = mediaStorage.storeAt(storageKey, file);
        } catch (IOException e) {
            deleteQuietly(storageKey);
            throw new IllegalStateException("Failed to store media file.", e);
        }
        String contentType = contentType(extension, stored.contentType());

        KeyHolder keyHolder = new GeneratedKeyHolder();
        try {
            jdbcTemplate.update(connection -> {
                PreparedStatement ps = connection.prepareStatement("""
                        INSERT INTO media_resources
                            (user_id, pet_id, record_id, storage_key, original_name, content_type, extension, file_size, status, visibility, created_at)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                        """, Statement.RETURN_GENERATED_KEYS);
                ps.setLong(1, userId);
                if (petId == null) {
                    ps.setObject(2, null);
                } else {
                    ps.setLong(2, petId);
                }
                if (recordId == null) {
                    ps.setObject(3, null);
                } else {
                    ps.setLong(3, recordId);
                }
                ps.setString(4, stored.storageKey());
                ps.setString(5, file.getOriginalFilename());
                ps.setString(6, contentType);
                ps.setString(7, extension);
                ps.setLong(8, stored.fileSize());
                ps.setString(9, "STORED");
                ps.setString(10, visibility);
                ps.setObject(11, UtcTime.toDatabase(Instant.now()));
                return ps;
            }, keyHolder);
        } catch (RuntimeException e) {
            deleteQuietly(stored.storageKey());
            throw e;
        }

        registerRollbackCleanup(stored.storageKey());
        jdbcTemplate.update("DELETE FROM media_storage_attempts WHERE storage_key=?", storageKey);

        Long mediaId = Objects.requireNonNull(keyHolder.getKey()).longValue();
        if ("PUBLIC".equals(visibility)) {
            return MediaResponse.publicMedia(mediaId, file.getOriginalFilename(), contentType, stored.fileSize(), "STORED");
        }
        return MediaResponse.of(mediaId, file.getOriginalFilename(), contentType, stored.fileSize(), "STORED");
    }

    private void reserveQuota(Long userId, long bytes, int items) {
        if (bytes == 0 && items == 0) return;
        int updated = jdbcTemplate.update("""
                UPDATE users SET media_bytes_used=media_bytes_used+?, media_items_used=media_items_used+?
                WHERE id=? AND media_bytes_used+? BETWEEN 0 AND ? AND media_items_used+? BETWEEN 0 AND ?
                """, bytes, items, userId, bytes, requestLimits.getMediaUserBytes(), items, requestLimits.getMediaUserItems());
        if (updated != 1) {
            throw new ApiException(HttpStatus.CONFLICT, "media-quota-exceeded", "Media quota exceeded",
                    "사진 저장 한도를 초과했어요. 기존 사진을 정리한 뒤 다시 시도해 주세요.",
                    "MEDIA_QUOTA_EXCEEDED");
        }
    }

    private long profileMediaBytes(Long userId, Long mediaId) {
        if (mediaId == null) return -1;
        var rows = jdbcTemplate.queryForList("""
                SELECT file_size FROM media_resources
                WHERE id=? AND user_id=? AND pet_id IS NULL AND record_id IS NULL
                """, mediaId, userId);
        return rows.isEmpty() ? -1 : ((Number) rows.getFirst().get("file_size")).longValue();
    }

    /** Call at the request boundary before starting a database transaction. Failed uploads still consume budget. */
    public void admitUpload(Long userId, int count) {
        if (count == 0) return;
        requestRateLimiter.consume(java.util.List.of(new RequestRateLimiter.Bucket(
                "media-upload-user", userId.toString(), requestLimits.getMediaUploadCapacity(),
                requestLimits.getMediaUploadRefillSeconds(), count)));
    }

    private void decrementQuota(Long userId, long bytes, int items) {
        jdbcTemplate.update("""
                UPDATE users SET media_bytes_used=GREATEST(media_bytes_used-?,0),
                                 media_items_used=GREATEST(media_items_used-?,0)
                WHERE id=?
                """, bytes, items, userId);
    }

    private void deleteOwnedMedia(Long userId, Long mediaId) {
        var rows = jdbcTemplate.queryForList("""
                SELECT storage_key,file_size FROM media_resources WHERE id=? AND user_id=?
                """, mediaId, userId);
        if (rows.isEmpty()) return;
        String key = (String) rows.getFirst().get("storage_key");
        jdbcTemplate.update("INSERT IGNORE INTO media_cleanup_queue(storage_key) VALUES (?)", key);
        int deleted = jdbcTemplate.update("DELETE FROM media_resources WHERE id=? AND user_id=?", mediaId, userId);
        if (deleted == 1) decrementQuota(userId, ((Number) rows.getFirst().get("file_size")).longValue(), 1);
    }

    private void validateFile(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new IllegalArgumentException("Media file is required.");
        }
        String extension = extension(file.getOriginalFilename());
        if (!ALLOWED_EXTENSIONS.contains(extension)) {
            throw new IllegalArgumentException("Unsupported media extension.");
        }
        if (file.getSize() > MAX_FILE_SIZE) {
            throw new IllegalArgumentException("Media file must be 5MB or smaller.");
        }
    }

    public void validateKeyedUpload(MultipartFile file) {
        MediaFileValidation.validate(file);
    }

    private String extension(String originalName) {
        if (originalName == null || !originalName.contains(".")) {
            throw new IllegalArgumentException("Media file extension is required.");
        }
        return originalName.substring(originalName.lastIndexOf('.') + 1).toLowerCase(Locale.ROOT);
    }

    private String contentType(String extension, String fallback) {
        return switch (extension) {
            case "jpg", "jpeg" -> "image/jpeg";
            case "png" -> "image/png";
            case "webp" -> "image/webp";
            default -> fallback;
        };
    }

    private void registerRollbackCleanup(String storageKey) {
        if (!TransactionSynchronizationManager.isSynchronizationActive()) {
            return;
        }
        TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
            @Override
            public void afterCompletion(int status) {
                if (status == STATUS_ROLLED_BACK) {
                    deleteQuietly(storageKey);
                }
            }
        });
    }

    private void deleteQuietly(String storageKey) {
        try {
            mediaStorage.delete(storageKey);
        } catch (IOException failure) {
            try {
                orphanCleanup.enqueue(storageKey);
            } catch (RuntimeException queueFailure) {
                // A separately committed storage attempt remains recoverable even if enqueue commit fails.
                log.error("Media cleanup enqueue failed; durable attempt will be recovered ({})",
                        queueFailure.getClass().getSimpleName());
            }
        }
    }

    private void ensureRecordBelongsToPet(Long petId, Long recordId) {
        Integer count = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM activity_records WHERE id = ? AND pet_id = ?",
                Integer.class,
                recordId,
                petId
        );
        if (count == null || count == 0) {
            throw new AccessDeniedException("Cannot attach media to this record.");
        }
    }

    private Map<String, Object> findMedia(Long mediaId) {
        var rows = jdbcTemplate.queryForList("""
                SELECT id, user_id, storage_key, content_type, visibility
                FROM media_resources
                WHERE id = ?
                """, mediaId);
        if (rows.isEmpty()) {
            throw new IllegalArgumentException("Media not found.");
        }
        return rows.getFirst();
    }

    private Pet findOwnedPet(User user, Long petId) {
        if (petId == null) {
            throw new IllegalArgumentException("Pet id must not be null.");
        }
        return petRepository.findById(petId)
                .filter(pet -> pet.isOwnedBy(user.getId()))
                .orElseThrow(() -> new AccessDeniedException("Cannot access this pet."));
    }

    private User findUser(Long actorId) {
        return userRepository.findById(actorId)
                .orElseThrow(() -> new IllegalStateException("User not found."));
    }
}
