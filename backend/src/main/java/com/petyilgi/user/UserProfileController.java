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
import io.swagger.v3.oas.annotations.tags.Tag;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;

@RestController
@RequestMapping("/api/v1/users/me")
@RequiredArgsConstructor
@Tag(name = "User Profile", description = "내 프로필 관리 API")
@SecurityRequirement(name = "bearerAuth")
public class UserProfileController {

    private final UserProfileService userProfileService;

    @GetMapping
    @Operation(summary = "내 프로필 조회")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "프로필 조회 성공")
    public ApiResponse<UserProfileResponse> getProfile(@AuthenticationPrincipal String email) {
        return ApiResponse.of(userProfileService.getProfile(email));
    }

    @PatchMapping
    @Operation(summary = "내 프로필 수정")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "프로필 수정 성공")
    public ApiResponse<UserProfileResponse> updateProfile(@AuthenticationPrincipal String email,
                                                          @Valid @RequestBody UserProfileUpdateRequest request) {
        return ApiResponse.of(userProfileService.updateProfile(email, request));
    }

    @PostMapping("/profile-image")
    @Operation(summary = "프로필 이미지 업로드")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "201", description = "이미지 업로드 성공")
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<UserProfileResponse> uploadProfileImage(@AuthenticationPrincipal String email,
                                                               @RequestParam("file") MultipartFile file) {
        return ApiResponse.of(userProfileService.uploadProfileImage(email, file));
    }
}
