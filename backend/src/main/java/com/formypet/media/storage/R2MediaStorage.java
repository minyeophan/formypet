package com.formypet.media.storage;

import org.springframework.web.multipart.MultipartFile;
import software.amazon.awssdk.core.ResponseBytes;
import software.amazon.awssdk.core.exception.SdkException;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.model.DeleteObjectRequest;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;

import java.io.IOException;
import java.time.YearMonth;
import java.time.format.DateTimeFormatter;
import java.util.UUID;

public class R2MediaStorage implements MediaStorage {

    private static final DateTimeFormatter MONTH_FORMAT = DateTimeFormatter.ofPattern("yyyyMM");

    private final S3Client s3Client;
    private final String bucket;

    public R2MediaStorage(S3Client s3Client, String bucket) {
        this.s3Client = s3Client;
        this.bucket = bucket;
    }

    @Override
    public StoredMedia store(Long userId, String folderName, String extension, MultipartFile file) throws IOException {
        String key = userId + "/" + folderName + "/" + YearMonth.now().format(MONTH_FORMAT)
                + "/" + UUID.randomUUID() + "." + extension;
        String contentType = file.getContentType();
        byte[] bytes = file.getBytes();
        try {
            s3Client.putObject(PutObjectRequest.builder()
                            .bucket(bucket)
                            .key(key)
                            .contentType(contentType)
                            .build(),
                    RequestBody.fromBytes(bytes));
        } catch (SdkException exception) {
            throw storageIOException("upload");
        }
        return new StoredMedia(key, contentType, file.getSize());
    }

    @Override
    public LoadedMedia load(String storageKey, String contentType) throws IOException {
        if (contentType == null) {
            throw new IllegalArgumentException("Content type must not be null.");
        }
        try {
            ResponseBytes<?> object = s3Client.getObjectAsBytes(GetObjectRequest.builder()
                    .bucket(bucket)
                    .key(storageKey)
                    .build());
            return new LoadedMedia(object.asByteArray(), contentType);
        } catch (SdkException exception) {
            throw storageIOException("download");
        }
    }

    @Override
    public void delete(String storageKey) throws IOException {
        try {
            s3Client.deleteObject(DeleteObjectRequest.builder()
                    .bucket(bucket)
                    .key(storageKey)
                    .build());
        } catch (SdkException exception) {
            throw storageIOException("delete");
        }
    }

    private IOException storageIOException(String operation) {
        return new IOException("Cloud media storage " + operation + " failed.");
    }
}
