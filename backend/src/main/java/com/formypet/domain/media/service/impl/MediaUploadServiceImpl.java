package com.formypet.domain.media.service.impl;

import com.formypet.domain.user.entity.User;
import com.formypet.domain.user.repository.UserRepository;
import com.formypet.domain.media.entity.MediaResource;
import com.formypet.domain.media.repository.MediaResourceRepository;
import com.formypet.domain.media.repository.jdbc.MediaQuotaRepository;
import com.formypet.domain.media.repository.jdbc.MediaWorkRepository;
import com.formypet.domain.media.repository.jdbc.MediaAttachmentRepository;
import com.formypet.domain.media.repository.query.MediaFile;
import com.formypet.common.exception.ApiException;
import com.formypet.common.ratelimit.RequestRateLimiter;
import com.formypet.common.ratelimit.RequestRateLimitProperties;
import com.formypet.domain.media.dto.response.MediaResponse;
import com.formypet.domain.media.storage.MediaStorage;
import com.formypet.domain.media.storage.StoredMedia;
import com.formypet.domain.pet.entity.Pet;
import com.formypet.domain.pet.repository.PetRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.List;

import com.formypet.domain.media.validation.MediaFileValidation;
import com.formypet.domain.media.validation.MediaUploadValidation;
import com.formypet.domain.media.service.MediaStorageAttempts;
import com.formypet.domain.media.storage.MediaRollbackCleanup;
import com.formypet.domain.media.service.MediaUploadService;

@Service
@RequiredArgsConstructor
public class MediaUploadServiceImpl implements MediaUploadService {

    private final UserRepository userRepository;
    private final PetRepository petRepository;
    private final MediaAttachmentRepository attachments;
    private final MediaResourceRepository mediaRepository;
    private final MediaQuotaRepository quotaRepository;
    private final MediaWorkRepository workRepository;
    private final MediaStorage mediaStorage;
    private final MediaStorageAttempts storageAttempts;
    private final RequestRateLimiter requestRateLimiter;
    private final RequestRateLimitProperties requestLimits;
    private final MediaRollbackCleanup rollbackCleanup;

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
        MediaUploadValidation.validateFile(file);
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
        MediaUploadValidation.validateFile(file);
        long replacedBytes = profileMediaBytes(user.getId(), replacedMediaId);
        int itemDelta = replacedBytes < 0 ? 1 : 0;
        reserveQuota(user.getId(), file.getSize() - Math.max(replacedBytes, 0), itemDelta);
        return storeAndInsert(user.getId(), null, null, "PRIVATE", "profile", file, true);
    }

    @Transactional
    public java.util.List<MediaResponse> uploadCommunityMedia(User user, java.util.List<MultipartFile> files) {
        files.forEach(MediaUploadValidation::validateFile);
        if (files.isEmpty()) return java.util.List.of();
        long totalBytes = files.stream().mapToLong(MultipartFile::getSize).sum();
        reserveQuota(user.getId(), totalBytes, files.size());
        return files.stream().map(file -> storeAndInsert(user.getId(), null, null, "PUBLIC", "community",
                file, true)).toList();
    }

    private MediaResponse storeAndInsert(Long userId, Long petId, Long recordId, String visibility,
                                         String folderName, MultipartFile file, boolean quotaReserved) {
        return storeAndInsert(userId, petId, recordId, visibility, folderName, file, quotaReserved,
                MediaResource.attachmentKind(petId, recordId));
    }

    private MediaResponse storeAndInsert(Long userId, Long petId, Long recordId, String visibility,
                                           String folderName, MultipartFile file, boolean quotaReserved, String mediaKind) {
        MediaUploadValidation.validateFile(file);
        if (!quotaReserved) reserveQuota(userId, file.getSize(), 1);
        String extension = MediaUploadValidation.extension(file.getOriginalFilename());
        String storageKey = MediaStorage.allocateKey(userId, folderName, extension);
        storageAttempts.begin(storageKey);
        workRepository.lockAttempt(storageKey);
        StoredMedia stored;
        try {
            stored = mediaStorage.storeAt(storageKey, file);
        } catch (IOException e) {
            rollbackCleanup.deleteQuietly(storageKey);
            throw new IllegalStateException("Failed to store media file.", e);
        }
        String contentType = MediaUploadValidation.contentType(extension, stored.contentType());

        MediaResource media;
        try {
            media = mediaRepository.saveAndFlush(MediaResource.stored(userId, petId, recordId,
                    stored.storageKey(), file.getOriginalFilename(), contentType, extension,
                    stored.fileSize(), visibility, mediaKind));
        } catch (RuntimeException e) {
            rollbackCleanup.deleteQuietly(stored.storageKey());
            throw e;
        }

        rollbackCleanup.registerRollbackCleanup(stored.storageKey());
        workRepository.finishAttempt(storageKey);

        Long mediaId = media.getId();
        if ("PUBLIC".equals(visibility)) {
            return MediaResponse.publicMedia(mediaId, file.getOriginalFilename(), contentType, stored.fileSize(), "STORED");
        }
        return MediaResponse.of(mediaId, file.getOriginalFilename(), contentType, stored.fileSize(), "STORED");
    }

    private void reserveQuota(Long userId, long bytes, int items) {
        if (bytes == 0 && items == 0) return;
        int updated = quotaRepository.reserve(userId, bytes, items,
                requestLimits.getMediaUserBytes(), requestLimits.getMediaUserItems());
        if (updated != 1) {
            throw new ApiException(HttpStatus.CONFLICT, "media-quota-exceeded", "Media quota exceeded",
                    "사진 저장 한도를 초과했어요. 기존 사진을 정리한 뒤 다시 시도해 주세요.",
                    "MEDIA_QUOTA_EXCEEDED");
        }
    }

    private long profileMediaBytes(Long userId, Long mediaId) {
        if (mediaId == null) return -1;
        return mediaRepository.profileFile(mediaId, userId).map(MediaFile::fileSize).orElse(-1L);
    }

    public void admitUpload(Long userId, int count) {
        if (count == 0) return;
        requestRateLimiter.consume(java.util.List.of(new RequestRateLimiter.Bucket(
                "media-upload-user", userId.toString(), requestLimits.getMediaUploadCapacity(),
                requestLimits.getMediaUploadRefillSeconds(), count)));
    }


    public void validateKeyedUpload(MultipartFile file) {
        MediaFileValidation.validate(file);
    }



    private void ensureRecordBelongsToPet(Long petId, Long recordId) {
        if (!attachments.recordBelongsToPet(recordId, petId)) {
            throw new AccessDeniedException("Cannot attach media to this record.");
        }
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
