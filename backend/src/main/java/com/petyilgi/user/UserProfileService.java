package com.petyilgi.user;

import com.petyilgi.auth.domain.User;
import com.petyilgi.auth.repository.UserRepository;
import com.petyilgi.media.MediaService;
import com.petyilgi.media.dto.MediaResponse;
import com.petyilgi.user.dto.UserProfileResponse;
import com.petyilgi.user.dto.UserProfileUpdateRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

@Service
@RequiredArgsConstructor
public class UserProfileService {

    private final UserRepository userRepository;
    private final MediaService mediaService;

    @Transactional(readOnly = true)
    public UserProfileResponse getProfile(String email) {
        return UserProfileResponse.of(findUser(email));
    }

    @Transactional
    public UserProfileResponse updateProfile(String email, UserProfileUpdateRequest request) {
        User user = findUser(email);
        user.updateNickname(request.nickname().trim());
        return UserProfileResponse.of(user);
    }

    @Transactional
    public UserProfileResponse uploadProfileImage(String email, MultipartFile file) {
        User user = findUser(email);
        Long previousMediaId = user.getProfileMediaId();
        MediaResponse media = mediaService.uploadUserProfileMedia(email, file);
        user.updateProfileMediaId(media.id());
        userRepository.flush();
        if (previousMediaId != null && !previousMediaId.equals(media.id())) {
            mediaService.deleteUserProfileMedia(user.getId(), previousMediaId);
        }
        return UserProfileResponse.of(user);
    }

    private User findUser(String email) {
        return userRepository.findByEmail(email)
                .orElseThrow(() -> new IllegalStateException("User not found."));
    }
}
