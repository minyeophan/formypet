package com.formypet.domain.media.service.impl;

import com.formypet.domain.user.entity.User;
import com.formypet.domain.media.dto.response.MediaResponse;
import com.formypet.domain.media.storage.LoadedMedia;
import org.springframework.web.multipart.MultipartFile;

import com.formypet.domain.media.service.MediaService;
import com.formypet.domain.media.service.MediaUploadService;
import com.formypet.domain.media.service.MediaQueryService;
import com.formypet.domain.media.service.MediaDeletionService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class MediaServiceImpl implements MediaService {
    private final MediaUploadService upload;
    private final MediaQueryService query;
    private final MediaDeletionService deletion;

    @Override
    public MediaResponse uploadPetMedia(Long actorId, Long petId, MultipartFile file) {
        return upload.uploadPetMedia(actorId, petId, file);
    }

    @Override
    public MediaResponse uploadRecordMedia(Long actorId, Long petId, Long recordId, MultipartFile file) {
        return upload.uploadRecordMedia(actorId, petId, recordId, file);
    }

    @Override
    public MediaResponse uploadPetLogDraftMedia(Long actorId, Long petId, MultipartFile file) {
        return upload.uploadPetLogDraftMedia(actorId, petId, file);
    }

    @Override
    public MediaResponse uploadUserProfileMedia(Long actorId, MultipartFile file) {
        return upload.uploadUserProfileMedia(actorId, file);
    }

    @Override
    public MediaResponse uploadUserProfileMedia(Long actorId, MultipartFile file, Long replacedMediaId) {
        return upload.uploadUserProfileMedia(actorId, file, replacedMediaId);
    }

    @Override
    public void deleteUserProfileMedia(Long userId, Long mediaId) {
        deletion.deleteUserProfileMedia(userId, mediaId);
    }

    @Override
    public void deleteReplacedUserProfileMedia(Long userId, Long mediaId) {
        deletion.deleteReplacedUserProfileMedia(userId, mediaId);
    }

    @Override
    public java.util.List<MediaResponse> uploadCommunityMedia(User user, java.util.List<MultipartFile> files) {
        return upload.uploadCommunityMedia(user, files);
    }

    @Override
    public void deleteCommunityMedia(Long userId, Long mediaId) {
        deletion.deleteCommunityMedia(userId, mediaId);
    }

    @Override
    public void deleteRecordMedia(Long userId, Long recordId) {
        deletion.deleteRecordMedia(userId, recordId);
    }

    @Override
    public void deletePetLogMedia(Long userId, Long petLogId) {
        deletion.deletePetLogMedia(userId, petLogId);
    }

    @Override
    public void lockPetLogMediaOwner(Long userId) {
        deletion.lockPetLogMediaOwner(userId);
    }

    @Override
    public void deletePetLogMediaIds(Long userId, java.util.List<Long> mediaIds) {
        deletion.deletePetLogMediaIds(userId, mediaIds);
    }

    @Override
    public void deletePetLogDataForPet(Long userId, Long petId) {
        deletion.deletePetLogDataForPet(userId, petId);
    }

    @Override
    public int cleanupExpiredPetLogDrafts() {
        return deletion.cleanupExpiredPetLogDrafts();
    }

    @Override
    public int[] imageDimensions(Long userId, Long mediaId) {
        return query.imageDimensions(userId, mediaId);
    }

    @Override
    public LoadedMedia load(Long actorId, Long mediaId) {
        return query.load(actorId, mediaId);
    }

    @Override
    public LoadedMedia loadPublic(Long mediaId) {
        return query.loadPublic(mediaId);
    }

    @Override
    public LoadedMedia loadUserProfileImage(Long userId) {
        return query.loadUserProfileImage(userId);
    }

    @Override
    public void admitUpload(Long userId, int count) {
        upload.admitUpload(userId, count);
    }

    @Override
    public void validateKeyedUpload(MultipartFile file) {
        upload.validateKeyedUpload(file);
    }
}
