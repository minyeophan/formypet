package com.petyilgi.media.storage;

import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;

public interface MediaStorage {
    StoredMedia store(Long userId, Long petId, String extension, MultipartFile file) throws IOException;

    LoadedMedia load(String storageKey, String contentType) throws IOException;
}
