package com.formypet.media;

import com.formypet.common.response.ApiResponse;
import com.formypet.media.dto.MediaResponse;
import com.formypet.media.storage.LoadedMedia;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import io.swagger.v3.oas.annotations.tags.Tag;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;

@RestController
@RequiredArgsConstructor
@Tag(name = "Media", description = "미디어 업로드 및 조회 API")
public class MediaController {

    private final MediaService mediaService;
    private final com.formypet.common.idempotency.IdempotencyService idempotency;

    @PostMapping("/api/v1/pets/{petId}/media")
    @Operation(summary = "반려동물 미디어 업로드")
    @SecurityRequirement(name = "bearerAuth")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "201", description = "업로드 성공")
    @ResponseStatus(org.springframework.http.HttpStatus.CREATED)
    public ApiResponse<MediaResponse> uploadPetMedia(@AuthenticationPrincipal(expression = "id") Long actorId,
                                                     @PathVariable Long petId,
                                                     @RequestHeader(value = "Idempotency-Key", required = false) String key,
                                                     @RequestParam("file") MultipartFile file) {
        return ApiResponse.of(idempotency.execute(actorId, "pet-media", petId.toString(), key, null,
                java.util.List.of(file), () -> {
                    if (key != null) mediaService.validateKeyedUpload(file);
                    mediaService.admitUpload(actorId, 1);
                    return mediaService.uploadPetMedia(actorId, petId, file);
                }, MediaResponse::id, id -> {
                    idempotency.requirePet(actorId, petId);
                    return idempotency.media(actorId, id);
                }));
    }

    @PostMapping("/api/v1/pets/{petId}/records/{recordId}/media")
    @Operation(summary = "활동 기록 미디어 업로드")
    @SecurityRequirement(name = "bearerAuth")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "201", description = "업로드 성공")
    @ResponseStatus(org.springframework.http.HttpStatus.CREATED)
    public ApiResponse<MediaResponse> uploadRecordMedia(@AuthenticationPrincipal(expression = "id") Long actorId,
                                                        @PathVariable Long petId,
                                                        @PathVariable Long recordId,
                                                        @RequestHeader(value = "Idempotency-Key", required = false) String key,
                                                     @RequestParam("file") MultipartFile file) {
        return ApiResponse.of(idempotency.execute(actorId, "record-media", petId + ":" + recordId, key, null,
                java.util.List.of(file), () -> {
                    if (key != null) mediaService.validateKeyedUpload(file);
                    mediaService.admitUpload(actorId, 1);
                    return mediaService.uploadRecordMedia(actorId, petId, recordId, file);
                }, MediaResponse::id, id -> {
                    idempotency.requireRecord(actorId, petId, recordId);
                    return idempotency.media(actorId, id);
                }));
    }

    @GetMapping("/api/v1/media/{mediaId}")
    @Operation(summary = "비공개 미디어 조회")
    @SecurityRequirement(name = "bearerAuth")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "미디어 조회 성공")
    public ResponseEntity<byte[]> load(@AuthenticationPrincipal(expression = "id") Long actorId,
                                       @PathVariable Long mediaId) {
        LoadedMedia media = mediaService.load(actorId, mediaId);
        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType(media.contentType()))
                .body(media.bytes());
    }

    @GetMapping("/api/v1/public/media/{mediaId}")
    @Operation(summary = "공개 미디어 조회")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "미디어 조회 성공")
    public ResponseEntity<byte[]> loadPublic(@PathVariable Long mediaId) {
        LoadedMedia media = mediaService.loadPublic(mediaId);
        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType(media.contentType()))
                .body(media.bytes());
    }
}
