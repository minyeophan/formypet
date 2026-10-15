package com.formypet.domain.media.service;

import com.formypet.auth.domain.User;
import com.formypet.domain.media.dto.response.MediaResponse;
import com.formypet.domain.media.storage.LoadedMedia;
import org.springframework.web.multipart.MultipartFile;

public interface MediaService {
    MediaResponse uploadPetMedia(Long actorId, Long petId, MultipartFile file);
    MediaResponse uploadRecordMedia(Long actorId, Long petId, Long recordId, MultipartFile file);
    MediaResponse uploadPetLogDraftMedia(Long actorId, Long petId, MultipartFile file);
    MediaResponse uploadUserProfileMedia(Long actorId, MultipartFile file);
    MediaResponse uploadUserProfileMedia(Long actorId, MultipartFile file, Long replacedMediaId);
    void deleteUserProfileMedia(Long userId, Long mediaId);
    void deleteReplacedUserProfileMedia(Long userId, Long mediaId);
    java.util.List<MediaResponse> uploadCommunityMedia(User user, java.util.List<MultipartFile> files);
    void deleteCommunityMedia(Long userId, Long mediaId);
    void deleteRecordMedia(Long userId, Long recordId);
    void deletePetLogMedia(Long userId, Long petLogId);
    void lockPetLogMediaOwner(Long userId);
    void deletePetLogMediaIds(Long userId, java.util.List<Long> mediaIds);
    void deletePetLogDataForPet(Long userId, Long petId);
    int cleanupExpiredPetLogDrafts();
    int[] imageDimensions(Long userId, Long mediaId);
    LoadedMedia load(Long actorId, Long mediaId);
    LoadedMedia loadPublic(Long mediaId);
    LoadedMedia loadUserProfileImage(Long userId);
    void admitUpload(Long userId, int count);
    void validateKeyedUpload(MultipartFile file);
}
