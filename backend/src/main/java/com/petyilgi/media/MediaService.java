package com.petyilgi.media;

import com.petyilgi.auth.domain.User;
import com.petyilgi.auth.repository.UserRepository;
import com.petyilgi.media.dto.MediaResponse;
import com.petyilgi.media.storage.LoadedMedia;
import com.petyilgi.media.storage.MediaStorage;
import com.petyilgi.media.storage.StoredMedia;
import com.petyilgi.pet.domain.Pet;
import com.petyilgi.pet.repository.PetRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.jdbc.support.KeyHolder;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
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
        return storeAndInsert(user.getId(), pet.getId(), null, file);
    }

    @Transactional
    public MediaResponse uploadRecordMedia(String email, Long petId, Long recordId, MultipartFile file) {
        User user = findUser(email);
        Pet pet = findOwnedPet(user, petId);
        ensureRecordBelongsToPet(pet.getId(), recordId);
        return storeAndInsert(user.getId(), pet.getId(), recordId, file);
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

    private MediaResponse storeAndInsert(Long userId, Long petId, Long recordId, MultipartFile file) {
        validateFile(file);
        String extension = extension(file.getOriginalFilename());
        StoredMedia stored;
        try {
            stored = mediaStorage.store(userId, petId, extension, file);
        } catch (IOException e) {
            throw new IllegalStateException("Failed to store media file.", e);
        }

        KeyHolder keyHolder = new GeneratedKeyHolder();
        jdbcTemplate.update(connection -> {
            PreparedStatement ps = connection.prepareStatement("""
                    INSERT INTO media_resources
                        (user_id, pet_id, record_id, storage_key, original_name, content_type, extension, file_size, status, created_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """, Statement.RETURN_GENERATED_KEYS);
            ps.setLong(1, userId);
            ps.setLong(2, petId);
            if (recordId == null) {
                ps.setObject(3, null);
            } else {
                ps.setLong(3, recordId);
            }
            ps.setString(4, stored.storageKey());
            ps.setString(5, file.getOriginalFilename());
            ps.setString(6, stored.contentType());
            ps.setString(7, extension);
            ps.setLong(8, stored.fileSize());
            ps.setString(9, "STORED");
            ps.setObject(10, LocalDateTime.now());
            return ps;
        }, keyHolder);

        Long mediaId = Objects.requireNonNull(keyHolder.getKey()).longValue();
        return MediaResponse.of(mediaId, file.getOriginalFilename(), stored.contentType(), stored.fileSize(), "STORED");
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
                SELECT id, user_id, storage_key, content_type
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
