package com.formypet.media.storage;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.mock.web.MockMultipartFile;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.core.ResponseBytes;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.DeleteObjectRequest;
import software.amazon.awssdk.services.s3.model.DeleteObjectResponse;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.model.GetObjectResponse;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.model.PutObjectResponse;
import software.amazon.awssdk.services.s3.model.S3Exception;

import java.io.IOException;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class R2MediaStorageTest {

    @Test
    void callerKnowsTheKeyEvenWhenPutResponseIsLost() throws Exception {
        String key = "42/profile/202610/known-attempt.png";
        when(s3Client.putObject(any(PutObjectRequest.class), any(RequestBody.class)))
                .thenThrow(S3Exception.builder().statusCode(503).build());
        assertThatThrownBy(() -> new R2MediaStorage(s3Client, BUCKET).storeAt(key,
                new MockMultipartFile("file", "photo.png", "image/png", new byte[]{1})))
                .isInstanceOf(IOException.class);
        var request = ArgumentCaptor.forClass(PutObjectRequest.class);
        verify(s3Client).putObject(request.capture(), any(RequestBody.class));
        assertThat(request.getValue().key()).isEqualTo(key);
    }

    private static final String BUCKET = "formypet-media-dev";

    @Mock
    private S3Client s3Client;

    @Test
    void storeUploadsBytesWithStableKeyShapeAndImageMetadata() throws Exception {
        byte[] bytes = {1, 2, 3, 4};
        var file = new MockMultipartFile("file", "photo.png", "image/png", bytes);
        when(s3Client.putObject(any(PutObjectRequest.class), any(RequestBody.class)))
                .thenReturn(PutObjectResponse.builder().build());

        var stored = new R2MediaStorage(s3Client, BUCKET).store(42L, "pet-9", "png", file);

        assertThat(stored.storageKey()).matches("42/pet-9/\\d{6}/[0-9a-f-]{36}\\.png");
        assertThat(stored.contentType()).isEqualTo("image/png");
        assertThat(stored.fileSize()).isEqualTo(bytes.length);

        var request = ArgumentCaptor.forClass(PutObjectRequest.class);
        var body = ArgumentCaptor.forClass(RequestBody.class);
        verify(s3Client).putObject(request.capture(), body.capture());
        assertThat(request.getValue().bucket()).isEqualTo(BUCKET);
        assertThat(request.getValue().key()).isEqualTo(stored.storageKey());
        assertThat(request.getValue().contentType()).isEqualTo("image/png");
        assertThat(body.getValue().contentStreamProvider().newStream().readAllBytes()).containsExactly(bytes);
    }

    @Test
    void loadFetchesObjectAndReturnsBytesWithDatabaseContentType() throws Exception {
        byte[] bytes = {9, 8, 7};
        when(s3Client.getObjectAsBytes(any(GetObjectRequest.class)))
                .thenReturn(ResponseBytes.fromByteArray(GetObjectResponse.builder().build(), bytes));

        var loaded = new R2MediaStorage(s3Client, BUCKET).load("42/profile/202609/photo.webp", "image/webp");

        assertThat(loaded.bytes()).containsExactly(bytes);
        assertThat(loaded.contentType()).isEqualTo("image/webp");
        var request = ArgumentCaptor.forClass(GetObjectRequest.class);
        verify(s3Client).getObjectAsBytes(request.capture());
        assertThat(request.getValue().bucket()).isEqualTo(BUCKET);
        assertThat(request.getValue().key()).isEqualTo("42/profile/202609/photo.webp");
    }

    @Test
    void deleteRemovesObjectFromConfiguredBucket() throws Exception {
        when(s3Client.deleteObject(any(DeleteObjectRequest.class)))
                .thenReturn(DeleteObjectResponse.builder().build());

        new R2MediaStorage(s3Client, BUCKET).delete("42/profile/202609/" + UUID.randomUUID() + ".jpg");

        var request = ArgumentCaptor.forClass(DeleteObjectRequest.class);
        verify(s3Client).deleteObject(request.capture());
        assertThat(request.getValue().bucket()).isEqualTo(BUCKET);
        assertThat(request.getValue().key()).startsWith("42/profile/202609/");
    }

    @Test
    void sdkStoreFailuresAreTranslatedToIoExceptions() {
        var file = new MockMultipartFile("file", "photo.png", "image/png", new byte[]{1});
        when(s3Client.putObject(any(PutObjectRequest.class), any(RequestBody.class)))
                .thenThrow(S3Exception.builder().message("storage unavailable").statusCode(503).build());

        assertThatThrownBy(() -> new R2MediaStorage(s3Client, BUCKET).store(42L, "profile", "png", file))
                .isInstanceOf(IOException.class);
    }

    @Test
    void sdkLoadFailuresAreTranslatedToIoExceptions() {
        when(s3Client.getObjectAsBytes(any(GetObjectRequest.class)))
                .thenThrow(S3Exception.builder().message("object missing").statusCode(404).build());

        assertThatThrownBy(() -> new R2MediaStorage(s3Client, BUCKET).load("42/profile/photo.png", "image/png"))
                .isInstanceOf(IOException.class);
    }

    @Test
    void sdkFailuresAreTranslatedToIoExceptionsForExistingCleanupFlow() {
        when(s3Client.deleteObject(any(DeleteObjectRequest.class)))
                .thenThrow(S3Exception.builder().message("storage unavailable").statusCode(503).build());

        assertThatThrownBy(() -> new R2MediaStorage(s3Client, BUCKET).delete("42/profile/photo.jpg"))
                .isInstanceOf(IOException.class)
                .hasMessage("Cloud media storage delete failed.")
                .hasNoCause();
    }
}
