package com.formypet.domain.media.service;

import com.formypet.domain.user.entity.User;
import com.formypet.domain.media.dto.response.MediaResponse;
import org.springframework.web.multipart.MultipartFile;

public interface MediaUploadService {
    MediaResponse uploadPetMedia(Long actorId, Long petId, MultipartFile file);
    MediaResponse uploadRecordMedia(Long actorId, Long petId, Long recordId, MultipartFile file);
    MediaResponse uploadPetLogDraftMedia(Long actorId, Long petId, MultipartFile file);
    MediaResponse uploadUserProfileMedia(Long actorId, MultipartFile file);
    MediaResponse uploadUserProfileMedia(Long actorId, MultipartFile file, Long replacedMediaId);
    java.util.List<MediaResponse> uploadCommunityMedia(User user, java.util.List<MultipartFile> files);
    void admitUpload(Long userId, int count);
    void validateKeyedUpload(MultipartFile file);
}
