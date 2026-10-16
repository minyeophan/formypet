package com.formypet.domain.user.service;

import com.formypet.domain.user.dto.request.UserProfileUpdateRequest;
import com.formypet.domain.user.dto.response.UserProfileResponse;

public interface UserProfileService {
    UserProfileResponse getProfile(Long actorId);
    UserProfileResponse updateProfile(Long actorId, UserProfileUpdateRequest request);
    UserProfileResponse uploadProfileImage(Long actorId, org.springframework.web.multipart.MultipartFile file);
}
