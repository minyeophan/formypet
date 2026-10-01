package com.formypet.user;

import com.formypet.media.MediaService;
import com.formypet.media.storage.LoadedMedia;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;
import io.swagger.v3.oas.annotations.tags.Tag;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;

@RestController
@RequiredArgsConstructor
@Tag(name = "Profile Images", description = "프로필 이미지 조회 API")
@SecurityRequirement(name = "bearerAuth")
public class UserProfileImageController {

    private final MediaService mediaService;

    @GetMapping("/api/v1/users/{userId}/profile-image")
    @Operation(summary = "프로필 이미지 조회")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "프로필 이미지 조회 성공")
    public ResponseEntity<byte[]> loadProfileImage(@PathVariable Long userId) {
        LoadedMedia media = mediaService.loadUserProfileImage(userId);
        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType(media.contentType()))
                .body(media.bytes());
    }
}
