package com.formypet.media;

import com.formypet.common.exception.ApiException;
import org.springframework.http.HttpStatus;
import org.springframework.web.multipart.MultipartFile;
import java.io.IOException;
import java.util.Locale;
import java.util.Set;

/** Signature validation for the prepared-image upload contract. MIME from multipart is not trusted. */
public final class MediaFileValidation {
    private MediaFileValidation() {}
    public static void validate(MultipartFile file) {
        if (file == null || file.isEmpty()) throw error("MEDIA_INVALID_FILE", "사진 파일을 읽을 수 없어요.");
        if (file.getSize() > 5L * 1024 * 1024) throw error("MEDIA_TOO_LARGE", "사진은 파일당 5MB 이하로 올려 주세요.");
        String name = file.getOriginalFilename();
        String ext = name == null || !name.contains(".") ? "" : name.substring(name.lastIndexOf('.') + 1).toLowerCase(Locale.ROOT);
        if (!Set.of("jpg", "jpeg", "png", "webp").contains(ext)) {
            throw error("MEDIA_UNSUPPORTED_FORMAT", "JPG, PNG, WebP 사진만 지원해요.");
        }
        byte[] b;
        try (var input = file.getInputStream()) { b = input.readNBytes(32); }
        catch (IOException e) { throw error("MEDIA_INVALID_FILE", "사진 파일을 읽을 수 없어요."); }
        boolean valid = switch (ext) {
            case "png" -> b.length >= 24 && (b[0] & 255) == 137 && b[1] == 80 && b[2] == 78 && b[3] == 71
                    && b[4] == 13 && b[5] == 10 && b[6] == 26 && b[7] == 10;
            case "jpg", "jpeg" -> b.length >= 3 && (b[0] & 255) == 255 && (b[1] & 255) == 216 && (b[2] & 255) == 255;
            case "webp" -> b.length >= 16 && b[0] == 'R' && b[1] == 'I' && b[2] == 'F' && b[3] == 'F'
                    && b[8] == 'W' && b[9] == 'E' && b[10] == 'B' && b[11] == 'P';
            default -> false;
        };
        if (!valid) throw error("MEDIA_INVALID_FILE", "사진의 실제 형식과 파일 확장자가 맞지 않아요.");
    }
    private static ApiException error(String code, String message) {
        return new ApiException(HttpStatus.BAD_REQUEST, "invalid-media", "Invalid media", message, code);
    }
}
