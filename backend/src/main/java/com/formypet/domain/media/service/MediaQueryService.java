package com.formypet.domain.media.service;

import com.formypet.domain.media.storage.LoadedMedia;

public interface MediaQueryService {
    int[] imageDimensions(Long userId, Long mediaId);
    LoadedMedia load(Long actorId, Long mediaId);
    LoadedMedia loadPublic(Long mediaId);
    LoadedMedia loadUserProfileImage(Long userId);
}
