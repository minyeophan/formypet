package com.formypet.domain.media;

import com.formypet.domain.media.validation.MediaUploadValidation;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockMultipartFile;
import static org.assertj.core.api.Assertions.*;

class MediaUploadValidationTest {
    @Test
    void ordinaryUploadKeepsExtensionOnlyContractAndNormalizesMime() {
        var file = new MockMultipartFile("file", "photo.PNG", "application/octet-stream", new byte[]{1,2});
        assertThatCode(() -> MediaUploadValidation.validateFile(file)).doesNotThrowAnyException();
        assertThat(MediaUploadValidation.extension(file.getOriginalFilename())).isEqualTo("png");
        assertThat(MediaUploadValidation.contentType("png", file.getContentType())).isEqualTo("image/png");
        assertThat(MediaUploadValidation.contentType("other", "fallback")).isEqualTo("fallback");
    }

    @Test
    void preservesMissingFileExtensionAndSizeErrors() {
        assertThatIllegalArgumentException().isThrownBy(() -> MediaUploadValidation.validateFile(null))
                .withMessage("Media file is required.");
        assertThatIllegalArgumentException().isThrownBy(() -> MediaUploadValidation.extension("photo"))
                .withMessage("Media file extension is required.");
        var invalid = new MockMultipartFile("file", "photo.gif", "image/gif", new byte[]{1});
        assertThatIllegalArgumentException().isThrownBy(() -> MediaUploadValidation.validateFile(invalid))
                .withMessage("Unsupported media extension.");
        var large = new MockMultipartFile("file", "photo.png", "image/png", new byte[5*1024*1024+1]);
        assertThatIllegalArgumentException().isThrownBy(() -> MediaUploadValidation.validateFile(large))
                .withMessage("Media file must be 5MB or smaller.");
    }
}
