package com.petyilgi.media;

import com.petyilgi.common.response.ApiResponse;
import com.petyilgi.media.dto.MediaResponse;
import com.petyilgi.media.storage.LoadedMedia;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequiredArgsConstructor
public class MediaController {

    private final MediaService mediaService;

    @PostMapping("/api/v1/pets/{petId}/media")
    @ResponseStatus(org.springframework.http.HttpStatus.CREATED)
    public ApiResponse<MediaResponse> uploadPetMedia(@AuthenticationPrincipal String email,
                                                     @PathVariable Long petId,
                                                     @RequestParam("file") MultipartFile file) {
        return ApiResponse.of(mediaService.uploadPetMedia(email, petId, file));
    }

    @PostMapping("/api/v1/pets/{petId}/records/{recordId}/media")
    @ResponseStatus(org.springframework.http.HttpStatus.CREATED)
    public ApiResponse<MediaResponse> uploadRecordMedia(@AuthenticationPrincipal String email,
                                                        @PathVariable Long petId,
                                                        @PathVariable Long recordId,
                                                        @RequestParam("file") MultipartFile file) {
        return ApiResponse.of(mediaService.uploadRecordMedia(email, petId, recordId, file));
    }

    @GetMapping("/api/v1/media/{mediaId}")
    public ResponseEntity<byte[]> load(@AuthenticationPrincipal String email,
                                       @PathVariable Long mediaId) {
        LoadedMedia media = mediaService.load(email, mediaId);
        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType(media.contentType()))
                .body(media.bytes());
    }

    @GetMapping("/api/v1/public/media/{mediaId}")
    public ResponseEntity<byte[]> loadPublic(@PathVariable Long mediaId) {
        LoadedMedia media = mediaService.loadPublic(mediaId);
        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType(media.contentType()))
                .body(media.bytes());
    }
}
