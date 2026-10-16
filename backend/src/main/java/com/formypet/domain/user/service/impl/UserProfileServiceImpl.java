package com.formypet.domain.user.service.impl;

import com.formypet.domain.user.service.UserProfileService;

import com.formypet.domain.user.entity.User;
import com.formypet.domain.user.repository.UserRepository;
import com.formypet.domain.media.service.MediaService;
import com.formypet.domain.media.dto.response.MediaResponse;
import com.formypet.domain.user.dto.response.UserProfileResponse;
import com.formypet.domain.user.dto.request.UserProfileUpdateRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

@Service
@RequiredArgsConstructor
public class UserProfileServiceImpl implements UserProfileService {

    private final UserRepository userRepository;
    private final MediaService mediaService;
    private final com.formypet.auth.SessionGuard sessions;

    @Transactional(readOnly = true)
    public UserProfileResponse getProfile(Long actorId) {
        return UserProfileResponse.of(findUser(actorId));
    }

    @Transactional
    public UserProfileResponse updateProfile(Long actorId, UserProfileUpdateRequest request) {
        sessions.lockCurrent(actorId);
        User user = findUser(actorId);
        user.updateNickname(request.nickname().trim());
        return UserProfileResponse.of(user);
    }

    @Transactional
    public UserProfileResponse uploadProfileImage(Long actorId, MultipartFile file) {
        sessions.lockCurrent(actorId);
        User user = findUser(actorId);
        Long previousMediaId = user.getProfileMediaId();
        MediaResponse media = mediaService.uploadUserProfileMedia(actorId, file, previousMediaId);
        user.updateProfileMediaId(media.id());
        userRepository.flush();
        if (previousMediaId != null && !previousMediaId.equals(media.id())) {
            mediaService.deleteReplacedUserProfileMedia(user.getId(), previousMediaId);
        }
        return UserProfileResponse.of(user);
    }

    private User findUser(Long actorId) {
        return userRepository.findById(actorId)
                .orElseThrow(() -> new IllegalStateException("User not found."));
    }
}
