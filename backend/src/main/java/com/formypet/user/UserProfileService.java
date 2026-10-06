package com.formypet.user;

import com.formypet.auth.domain.User;
import com.formypet.auth.repository.UserRepository;
import com.formypet.media.MediaService;
import com.formypet.media.dto.MediaResponse;
import com.formypet.user.dto.UserProfileResponse;
import com.formypet.user.dto.UserProfileUpdateRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

@Service
@RequiredArgsConstructor
public class UserProfileService {

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
