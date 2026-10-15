package com.formypet.domain.media.validation;

import java.util.Locale;
import java.util.Set;
import org.springframework.web.multipart.MultipartFile;

/** Legacy ordinary-upload validation; keyed uploads use MediaFileValidation. */
public final class MediaUploadValidation {
    private MediaUploadValidation() {}
    private static final long MAX_FILE_SIZE = 5L * 1024 * 1024;
    private static final Set<String> ALLOWED_EXTENSIONS = Set.of("jpg", "jpeg", "png", "webp");

    public static void validateFile(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new IllegalArgumentException("Media file is required.");
        }
        String extension = extension(file.getOriginalFilename());
        if (!ALLOWED_EXTENSIONS.contains(extension)) {
            throw new IllegalArgumentException("Unsupported media extension.");
        }
        if (file.getSize() > MAX_FILE_SIZE) {
            throw new IllegalArgumentException("Media file must be 5MB or smaller.");
        }
    }

    public static String extension(String originalName) {
        if (originalName == null || !originalName.contains(".")) {
            throw new IllegalArgumentException("Media file extension is required.");
        }
        return originalName.substring(originalName.lastIndexOf('.') + 1).toLowerCase(Locale.ROOT);
    }

    public static String contentType(String extension, String fallback) {
        return switch (extension) {
            case "jpg", "jpeg" -> "image/jpeg";
            case "png" -> "image/png";
            case "webp" -> "image/webp";
            default -> fallback;
        };
    }
}
