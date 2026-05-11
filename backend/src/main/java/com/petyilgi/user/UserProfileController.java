package com.petyilgi.user;

import com.petyilgi.common.response.ApiResponse;
import com.petyilgi.user.dto.UserProfileResponse;
import com.petyilgi.user.dto.UserProfileUpdateRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/v1/users/me")
@RequiredArgsConstructor
public class UserProfileController {

    private final UserProfileService userProfileService;

    @GetMapping
    public ApiResponse<UserProfileResponse> getProfile(@AuthenticationPrincipal String email) {
        return ApiResponse.of(userProfileService.getProfile(email));
    }

    @PatchMapping
    public ApiResponse<UserProfileResponse> updateProfile(@AuthenticationPrincipal String email,
                                                          @Valid @RequestBody UserProfileUpdateRequest request) {
        return ApiResponse.of(userProfileService.updateProfile(email, request));
    }

    @PostMapping("/profile-image")
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<UserProfileResponse> uploadProfileImage(@AuthenticationPrincipal String email,
                                                               @RequestParam("file") MultipartFile file) {
        return ApiResponse.of(userProfileService.uploadProfileImage(email, file));
    }
}
