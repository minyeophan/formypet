package com.formypet.domain.media.service;


public interface MediaDeletionService {
    void deleteUserProfileMedia(Long userId, Long mediaId);
    void deleteReplacedUserProfileMedia(Long userId, Long mediaId);
    void deleteCommunityMedia(Long userId, Long mediaId);
    void deleteRecordMedia(Long userId, Long recordId);
    void deletePetLogMedia(Long userId, Long petLogId);
    void lockPetLogMediaOwner(Long userId);
    void deletePetLogMediaIds(Long userId, java.util.List<Long> mediaIds);
    void deletePetLogDataForPet(Long userId, Long petId);
    int cleanupExpiredPetLogDrafts();
}
