package com.petyilgi.media.storage;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.YearMonth;
import java.time.format.DateTimeFormatter;
import java.util.UUID;

@Component
public class LocalMediaStorage implements MediaStorage {

    private static final DateTimeFormatter MONTH_FORMAT = DateTimeFormatter.ofPattern("yyyyMM");

    private final Path root;

    public LocalMediaStorage(@Value("${app.media.storage-root:storage}") String storageRoot) {
        this.root = Path.of(storageRoot);
    }

    @Override
    public StoredMedia store(Long userId, Long petId, String extension, MultipartFile file) throws IOException {
        String month = YearMonth.now().format(MONTH_FORMAT);
        String filename = UUID.randomUUID() + "." + extension;
        Path relativePath = Path.of(userId.toString(), petId.toString(), month, filename);
        Path target = root.resolve(relativePath);
        Files.createDirectories(target.getParent());
        file.transferTo(target);
        return new StoredMedia(relativePath.toString().replace('\\', '/'), file.getContentType(), file.getSize());
    }

    @Override
    public LoadedMedia load(String storageKey, String contentType) throws IOException {
        Path target = root.resolve(storageKey).normalize();
        if (!target.startsWith(root.normalize())) {
            throw new IllegalArgumentException("Invalid media path.");
        }
        return new LoadedMedia(Files.readAllBytes(target), contentType);
    }
}
