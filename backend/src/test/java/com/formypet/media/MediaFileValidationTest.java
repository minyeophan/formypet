package com.formypet.media;

import com.formypet.common.exception.ApiException;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockMultipartFile;
import static org.assertj.core.api.Assertions.*;

class MediaFileValidationTest {
    @Test void rejectsDisguisedFile() {
        assertThatThrownBy(() -> MediaFileValidation.validate(new MockMultipartFile(
                "file", "photo.png", "image/png", new byte[]{1, 2, 3})))
                .isInstanceOf(ApiException.class)
                .satisfies(error -> assertThat(((ApiException) error).errorCode()).isEqualTo("MEDIA_INVALID_FILE"));
    }
    @Test void acceptsPngWithGenericMultipartMime() {
        var png = java.util.Base64.getDecoder().decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLttAAAAABJRU5ErkJggg==");
        assertThatCode(() -> MediaFileValidation.validate(new MockMultipartFile(
                "file", "photo.png", "application/octet-stream", png))).doesNotThrowAnyException();
    }
    @Test void distinguishesTooLargeFromUnsupportedFormat() {
        assertThatThrownBy(() -> MediaFileValidation.validate(new MockMultipartFile(
                "file", "photo.png", "image/png", new byte[5 * 1024 * 1024 + 1])))
                .satisfies(error -> assertThat(((ApiException) error).errorCode()).isEqualTo("MEDIA_TOO_LARGE"));
        assertThatThrownBy(() -> MediaFileValidation.validate(new MockMultipartFile(
                "file", "photo.heic", "image/heic", new byte[]{1})))
                .satisfies(error -> assertThat(((ApiException) error).errorCode()).isEqualTo("MEDIA_UNSUPPORTED_FORMAT"));
    }
    @Test void allowsExactlyFiveMebibytes() {
        byte[] bytes = new byte[5 * 1024 * 1024];
        byte[] signature = new byte[]{(byte)137,80,78,71,13,10,26,10};
        System.arraycopy(signature,0,bytes,0,signature.length);
        assertThatCode(() -> MediaFileValidation.validate(new MockMultipartFile(
                "file","boundary.png","image/png",bytes))).doesNotThrowAnyException();
    }
}
