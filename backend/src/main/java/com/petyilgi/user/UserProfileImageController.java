package com.petyilgi.user;

import com.petyilgi.media.MediaService;
import com.petyilgi.media.storage.LoadedMedia;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequiredArgsConstructor
public class UserProfileImageController {

    private final MediaService mediaService;

    @GetMapping("/api/v1/users/{userId}/profile-image")
    public ResponseEntity<byte[]> loadProfileImage(@PathVariable Long userId) {
        LoadedMedia media = mediaService.loadUserProfileImage(userId);
        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType(media.contentType()))
                .body(media.bytes());
    }
}
