package com.formypet.media.storage;

import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;

public interface MediaStorage {
    static String allocateKey(Long userId, String folderName, String extension) {
        return userId + "/" + folderName + "/" + java.time.YearMonth.now().format(
                java.time.format.DateTimeFormatter.ofPattern("yyyyMM")) + "/" + java.util.UUID.randomUUID() + "." + extension;
    }

    default StoredMedia store(Long userId, String folderName, String extension, MultipartFile file) throws IOException {
        return storeAt(allocateKey(userId, folderName, extension), file);
    }

    StoredMedia storeAt(String storageKey, MultipartFile file) throws IOException;

    LoadedMedia load(String storageKey, String contentType) throws IOException;

    void delete(String storageKey) throws IOException;
}
