package com.formypet.domain.media.service.impl;

import com.formypet.domain.user.entity.User;
import com.formypet.domain.user.repository.UserRepository;
import com.formypet.domain.media.entity.MediaResource;
import com.formypet.domain.media.repository.MediaResourceRepository;
import com.formypet.domain.media.repository.jdbc.MediaAttachmentRepository;
import com.formypet.common.exception.ApiException;
import com.formypet.domain.media.storage.LoadedMedia;
import com.formypet.domain.media.storage.MediaStorage;
import com.formypet.domain.media.storage.MediaImageDimensions;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.io.IOException;

import com.formypet.domain.media.service.MediaQueryService;

@Service
@RequiredArgsConstructor
public class MediaQueryServiceImpl implements MediaQueryService {
    private final UserRepository userRepository;
    private final MediaAttachmentRepository attachments;
    private final MediaResourceRepository mediaRepository;
    private final MediaStorage mediaStorage;
    private final MediaImageDimensions imageDimensions;

    @Transactional(readOnly = true)
    public int[] imageDimensions(Long userId, Long mediaId) {
        var media = mediaRepository.petLogLocation(mediaId, userId)
                .orElseThrow(() -> new AccessDeniedException("Cannot use this photo."));
        try {
            var loaded = mediaStorage.load(media.storageKey(), media.contentType());
            return imageDimensions.read(loaded.bytes());
        } catch(IOException e) { throw new IllegalStateException("Failed to read photo dimensions.",e); }
    }



    @Transactional(readOnly = true)
    public LoadedMedia load(Long actorId, Long mediaId) {
        User user = findUser(actorId);
        MediaResource media = findMedia(mediaId);
        if (!media.isOwnedBy(user.getId())) {
            throw new AccessDeniedException("Cannot access media owned by another user.");
        }
        try {
            return mediaStorage.load(media.getStorageKey(), media.getContentType());
        } catch (IOException e) {
            throw new IllegalStateException("Failed to read media file.", e);
        }
    }

    @Transactional(readOnly = true)
    public LoadedMedia loadPublic(Long mediaId) {
        MediaResource media = findMedia(mediaId);
        if (!media.isPublic()) {
            throw new AccessDeniedException("Cannot access private media from public endpoint.");
        }
        try {
            return mediaStorage.load(media.getStorageKey(), media.getContentType());
        } catch (IOException e) {
            throw new IllegalStateException("Failed to read media file.", e);
        }
    }

    @Transactional(readOnly = true)
    public LoadedMedia loadUserProfileImage(Long userId) {
        var media = attachments.profileImage(userId).orElseThrow(() -> new ApiException(
                    HttpStatus.NOT_FOUND,
                    "profile-image-not-found",
                    "Profile Image Not Found",
                    "Profile image not found.",
                    "PROFILE_IMAGE_NOT_FOUND"
            ));
        try {
            return mediaStorage.load(media.storageKey(), media.contentType());
        } catch (IOException e) {
            throw new IllegalStateException("Failed to read media file.", e);
        }
    }

    private MediaResource findMedia(Long mediaId) {
        return mediaRepository.findById(mediaId)
                .orElseThrow(() -> new IllegalArgumentException("Media not found."));
    }

    private User findUser(Long actorId) {
        return userRepository.findById(actorId)
                .orElseThrow(() -> new IllegalStateException("User not found."));
    }
}
