package com.petyilgi.media.dto;

public record MediaResponse(
        Long id,
        String url,
        String originalName,
        String contentType,
        long fileSize,
        String status
) {
    public static MediaResponse of(Long id, String originalName, String contentType, long fileSize, String status) {
        return new MediaResponse(id, "/api/v1/media/" + id, originalName, contentType, fileSize, status);
    }
}
