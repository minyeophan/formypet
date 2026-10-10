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
import java.util.List;
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
    public MediaResponse uploadPetLogDraftMedia(Long actorId, Long petId, MultipartFile file) {
        User user = findUser(actorId);
        findOwnedPet(user, petId);
        validateFile(file);
        reserveQuota(user.getId(), file.getSize(), 1);
        return storeAndInsert(user.getId(), petId, null, "PRIVATE", "pet-log-" + petId, file, true, "PET_LOG_DRAFT");
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

    @Transactional
    public void deletePetLogMedia(Long userId, Long petLogId) {
        var owners = jdbcTemplate.queryForList("SELECT id FROM users WHERE id=? FOR UPDATE", Long.class, userId);
        if (owners.isEmpty()) return;
        var rows = jdbcTemplate.queryForList("""
                SELECT m.id,m.storage_key,m.file_size FROM media_resources m
                JOIN pet_log_media pm ON pm.media_id=m.id
                JOIN pet_logs pl ON pl.id=pm.pet_log_id
                WHERE pl.id=? AND pl.user_id=? AND m.user_id=? AND m.media_kind='PET_LOG' FOR UPDATE
                """, petLogId,userId,userId);
        if (rows.isEmpty()) return;
        deletePetLogMediaRows(userId, rows);
    }

    /** Serialize pet log media mutations with uploads and draft cleanup using the same owner-first lock order. */
    @Transactional
    public void lockPetLogMediaOwner(Long userId) {
        var owners = jdbcTemplate.queryForList("SELECT id FROM users WHERE id=? FOR UPDATE", Long.class, userId);
        if (owners.isEmpty()) throw new IllegalStateException("Media owner no longer exists.");
    }

    @Transactional
    public void deletePetLogMediaIds(Long userId, java.util.List<Long> mediaIds) {
        if (mediaIds.isEmpty()) return;
        var owners = jdbcTemplate.queryForList("SELECT id FROM users WHERE id=? FOR UPDATE", Long.class, userId);
        if (owners.isEmpty()) return;
        String placeholders = String.join(",", java.util.Collections.nCopies(mediaIds.size(), "?"));
        var rows = jdbcTemplate.queryForList("SELECT id,storage_key,file_size FROM media_resources WHERE user_id=? AND media_kind='PET_LOG' AND id IN ("+placeholders+") FOR UPDATE", prepend(userId, mediaIds));
        if (!rows.isEmpty()) deletePetLogMediaRows(userId, rows);
    }

    @Transactional
    public void deletePetLogDataForPet(Long userId, Long petId) {
        var owners=jdbcTemplate.queryForList("SELECT id FROM users WHERE id=? FOR UPDATE",Long.class,userId);
        if(owners.isEmpty()) return;
        var rows=jdbcTemplate.queryForList("SELECT id,storage_key,file_size FROM media_resources WHERE user_id=? AND pet_id=? AND media_kind IN ('PET_LOG_DRAFT','PET_LOG') FOR UPDATE",userId,petId);
        jdbcTemplate.update("DELETE FROM pet_logs WHERE user_id=? AND pet_id=?",userId,petId);
        jdbcTemplate.update("DELETE FROM pet_log_preferences WHERE user_id=? AND pet_id=?",userId,petId);
        if(rows.isEmpty()) return;
        for(var row:rows) jdbcTemplate.update("INSERT IGNORE INTO media_cleanup_queue(storage_key) VALUES (?)",row.get("storage_key"));
        int deleted=jdbcTemplate.update("DELETE FROM media_resources WHERE user_id=? AND pet_id=? AND media_kind IN ('PET_LOG_DRAFT','PET_LOG')",userId,petId);
        if(deleted!=rows.size()) throw new IllegalStateException("Pet log media changed during pet deletion.");
        long bytes=rows.stream().mapToLong(row->((Number)row.get("file_size")).longValue()).sum();
        decrementQuota(userId,bytes,deleted);
    }

    @Transactional
    public int cleanupExpiredPetLogDrafts() {
        List<Long> userIds=jdbcTemplate.queryForList("SELECT DISTINCT user_id FROM media_resources WHERE media_kind='PET_LOG_DRAFT' AND created_at < UTC_TIMESTAMP(6)-INTERVAL 24 HOUR ORDER BY user_id",Long.class);
        int total=0;
        for(Long userId:userIds) {
            var owners=jdbcTemplate.queryForList("SELECT id FROM users WHERE id=? FOR UPDATE",Long.class,userId);
            if(owners.isEmpty()) continue;
            var rows=jdbcTemplate.queryForList("SELECT id,storage_key,file_size FROM media_resources WHERE user_id=? AND media_kind='PET_LOG_DRAFT' AND created_at < UTC_TIMESTAMP(6)-INTERVAL 24 HOUR FOR UPDATE",userId);
            if(rows.isEmpty()) continue;
            for(var row:rows) jdbcTemplate.update("INSERT IGNORE INTO media_cleanup_queue(storage_key) VALUES (?)",row.get("storage_key"));
            int deleted=jdbcTemplate.update("DELETE FROM media_resources WHERE user_id=? AND media_kind='PET_LOG_DRAFT' AND created_at < UTC_TIMESTAMP(6)-INTERVAL 24 HOUR",userId);
            if(deleted!=rows.size()) throw new IllegalStateException("Expired pet log drafts changed during cleanup.");
            long bytes=rows.stream().mapToLong(row->((Number)row.get("file_size")).longValue()).sum();
            decrementQuota(userId,bytes,deleted);
            total+=deleted;
        }
        return total;
    }

    @Transactional(readOnly = true)
    public int[] imageDimensions(Long userId, Long mediaId) {
        var rows=jdbcTemplate.queryForList("SELECT storage_key,content_type FROM media_resources WHERE id=? AND user_id=? AND media_kind IN ('PET_LOG_DRAFT','PET_LOG') AND status='STORED'",mediaId,userId);
        if(rows.isEmpty()) throw new AccessDeniedException("Cannot use this photo.");
        try {
            var loaded=mediaStorage.load((String)rows.getFirst().get("storage_key"),(String)rows.getFirst().get("content_type"));
            try(var input=javax.imageio.ImageIO.createImageInputStream(new java.io.ByteArrayInputStream(loaded.bytes()))) {
                var readers=javax.imageio.ImageIO.getImageReaders(input);
                if(readers.hasNext()) {
                    var reader=readers.next();
                    try {
                        reader.setInput(input,true,true);
                        return checkedDimensions(reader.getWidth(0),reader.getHeight(0));
                    } finally { reader.dispose(); }
                }
            }
            int[] webp=webpDimensions(loaded.bytes());
            if(webp!=null) return checkedDimensions(webp[0],webp[1]);
            throw new IllegalArgumentException("사진 파일을 읽을 수 없습니다.");
        } catch(IOException e) { throw new IllegalStateException("Failed to read photo dimensions.",e); }
    }

    private int[] checkedDimensions(int width,int height) {
        if(width<=0||height<=0||(long)width*height>50_000_000L) throw new IllegalArgumentException("사진은 5천만 화소 이하로 선택해 주세요.");
        return new int[]{width,height};
    }

    private int[] webpDimensions(byte[] b) {
        if(b.length<30||b[0]!='R'||b[1]!='I'||b[2]!='F'||b[3]!='F'||b[8]!='W'||b[9]!='E'||b[10]!='B'||b[11]!='P') return null;
        for(int i=12;i+8<b.length;){String chunk=new String(b,i,4,java.nio.charset.StandardCharsets.US_ASCII);int size=(b[i+4]&255)|((b[i+5]&255)<<8)|((b[i+6]&255)<<16)|((b[i+7]&255)<<24);int p=i+8;if(size<0||p+size>b.length)return null;
            if("VP8X".equals(chunk)&&size>=10)return new int[]{1+(b[p+4]&255)+((b[p+5]&255)<<8)+((b[p+6]&255)<<16),1+(b[p+7]&255)+((b[p+8]&255)<<8)+((b[p+9]&255)<<16)};
            if("VP8L".equals(chunk)&&size>=5&&(b[p]&255)==0x2f){int bits=(b[p+1]&255)|((b[p+2]&255)<<8)|((b[p+3]&255)<<16)|((b[p+4]&255)<<24);return new int[]{(bits&0x3fff)+1,((bits>>14)&0x3fff)+1};}
            if("VP8 ".equals(chunk)&&size>=10){for(int j=p;j+6<p+size;j++)if((b[j]&255)==0x9d&&(b[j+1]&255)==0x01&&(b[j+2]&255)==0x2a)return new int[]{((b[j+4]&255)<<8|(b[j+3]&255))&0x3fff,((b[j+6]&255)<<8|(b[j+5]&255))&0x3fff};}
            i=p+size+(size&1);
        }return null;
    }

    private void deletePetLogMediaRows(Long userId, java.util.List<java.util.Map<String,Object>> rows) {
        for (var row: rows) jdbcTemplate.update("INSERT IGNORE INTO media_cleanup_queue(storage_key) VALUES (?)",row.get("storage_key"));
        String placeholders = String.join(",", java.util.Collections.nCopies(rows.size(), "?"));
        Object[] ids = new Object[rows.size()+1]; ids[0]=userId;
        for(int i=0;i<rows.size();i++) ids[i+1]=rows.get(i).get("id");
        int deleted=jdbcTemplate.update("DELETE FROM media_resources WHERE user_id=? AND media_kind='PET_LOG' AND id IN ("+placeholders+")",ids);
        if (deleted != rows.size()) throw new IllegalStateException("Pet log media changed during deletion.");
        long bytes=rows.stream().mapToLong(row->((Number)row.get("file_size")).longValue()).sum();
        decrementQuota(userId,bytes,deleted);
    }

    private Object[] prepend(Object first, java.util.List<Long> values) {
        Object[] result=new Object[values.size()+1]; result[0]=first;
        for(int i=0;i<values.size();i++) result[i+1]=values.get(i);
        return result;
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
        return storeAndInsert(userId, petId, recordId, visibility, folderName, file, quotaReserved,
                recordId != null ? "ACTIVITY_RECORD" : petId != null ? "PET_PROFILE" : "GENERAL");
    }

    private MediaResponse storeAndInsert(Long userId, Long petId, Long recordId, String visibility,
                                           String folderName, MultipartFile file, boolean quotaReserved, String mediaKind) {
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
                            (user_id, pet_id, record_id, storage_key, original_name, content_type, extension, file_size, status, visibility, created_at, media_kind)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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
                ps.setString(12, mediaKind);
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
