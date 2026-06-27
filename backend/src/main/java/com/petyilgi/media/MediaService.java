package com.petyilgi.media;

import com.petyilgi.auth.domain.User;
import com.petyilgi.auth.repository.UserRepository;
import com.petyilgi.common.exception.ApiException;
import com.petyilgi.media.dto.MediaResponse;
import com.petyilgi.media.storage.LoadedMedia;
import com.petyilgi.media.storage.MediaStorage;
import com.petyilgi.media.storage.StoredMedia;
import com.petyilgi.pet.domain.Pet;
import com.petyilgi.pet.repository.PetRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
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
import java.time.LocalDateTime;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;
import java.util.Set;

@Service
@RequiredArgsConstructor
public class MediaService {

    private static final long MAX_FILE_SIZE = 5L * 1024 * 1024;
    private static final Set<String> ALLOWED_EXTENSIONS = Set.of("jpg", "jpeg", "png", "webp");

    private final UserRepository userRepository;
    private final PetRepository petRepository;
    private final JdbcTemplate jdbcTemplate;
    private final MediaStorage mediaStorage;

    @Transactional
    public MediaResponse uploadPetMedia(String email, Long petId, MultipartFile file) {
        User user = findUser(email);
        Pet pet = findOwnedPet(user, petId);
        return storeAndInsert(user.getId(), pet.getId(), null, "PRIVATE", "pet-" + pet.getId(), file);
    }

    @Transactional
    public MediaResponse uploadRecordMedia(String email, Long petId, Long recordId, MultipartFile file) {
        User user = findUser(email);
        Pet pet = findOwnedPet(user, petId);
        ensureRecordBelongsToPet(pet.getId(), recordId);
        return storeAndInsert(user.getId(), pet.getId(), recordId, "PRIVATE", "pet-" + pet.getId(), file);
    }

    @Transactional
    public MediaResponse uploadUserProfileMedia(String email, MultipartFile file) {
        User user = findUser(email);
        return storeAndInsert(user.getId(), null, null, "PRIVATE", "profile", file);
    }

    @Transactional
    public void deleteUserProfileMedia(Long userId, Long mediaId) {
        var rows = jdbcTemplate.queryForList("""
                SELECT storage_key
                FROM media_resources
                WHERE id = ? AND user_id = ? AND pet_id IS NULL AND record_id IS NULL
                """, mediaId, userId);
        if (rows.isEmpty()) {
            return;
        }

        String storageKey = (String) rows.getFirst().get("storage_key");
        jdbcTemplate.update("DELETE FROM media_resources WHERE id = ? AND user_id = ?", mediaId, userId);
        registerAfterCommitCleanup(storageKey);
    }

    @Transactional
    public MediaResponse uploadCommunityMedia(User user, MultipartFile file) {
        return storeAndInsert(user.getId(), null, null, "PUBLIC", "community", file);
    }

    @Transactional(readOnly = true)
    public LoadedMedia load(String email, Long mediaId) {
        User user = findUser(email);
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

    private MediaResponse storeAndInsert(Long userId, Long petId, Long recordId, String visibility, String folderName, MultipartFile file) {
        validateFile(file);
        String extension = extension(file.getOriginalFilename());
        StoredMedia stored;
        try {
            stored = mediaStorage.store(userId, folderName, extension, file);
        } catch (IOException e) {
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
                ps.setObject(11, LocalDateTime.now());
                return ps;
            }, keyHolder);
        } catch (RuntimeException e) {
            deleteQuietly(stored.storageKey());
            throw e;
        }

        registerRollbackCleanup(stored.storageKey());

        Long mediaId = Objects.requireNonNull(keyHolder.getKey()).longValue();
        if ("PUBLIC".equals(visibility)) {
            return MediaResponse.publicMedia(mediaId, file.getOriginalFilename(), contentType, stored.fileSize(), "STORED");
        }
        return MediaResponse.of(mediaId, file.getOriginalFilename(), contentType, stored.fileSize(), "STORED");
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

    private void registerAfterCommitCleanup(String storageKey) {
        if (!TransactionSynchronizationManager.isSynchronizationActive()) {
            deleteQuietly(storageKey);
            return;
        }
        TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
            @Override
            public void afterCommit() {
                deleteQuietly(storageKey);
            }
        });
    }

    private void deleteQuietly(String storageKey) {
        try {
            mediaStorage.delete(storageKey);
        } catch (IOException ignored) {
            // Best-effort orphan cleanup.
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
        return petRepository.findById(petId)
                .filter(pet -> pet.isOwnedBy(user.getId()))
                .orElseThrow(() -> new AccessDeniedException("Cannot access this pet."));
    }

    private User findUser(String email) {
        return userRepository.findByEmail(email)
                .orElseThrow(() -> new IllegalStateException("User not found."));
    }
}
