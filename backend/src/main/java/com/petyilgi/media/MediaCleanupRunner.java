package com.petyilgi.media;

import com.petyilgi.media.storage.MediaStorage;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import java.util.List;

@Slf4j
@Component
@RequiredArgsConstructor
public class MediaCleanupRunner implements ApplicationRunner {

    private static final String SELECT_SQL = """
            SELECT storage_key
            FROM media_cleanup_queue
            ORDER BY created_at, storage_key
            """;
    private static final String DELETE_SQL = "DELETE FROM media_cleanup_queue WHERE storage_key = ?";

    private final JdbcTemplate jdbcTemplate;
    private final MediaStorage mediaStorage;

    @Override
    public void run(ApplicationArguments args) {
        List<String> storageKeys;
        try {
            storageKeys = jdbcTemplate.queryForList(SELECT_SQL, String.class);
        } catch (RuntimeException exception) {
            log.error("Failed to read media cleanup queue; startup will continue.", exception);
            return;
        }

        for (String storageKey : storageKeys) {
            try {
                mediaStorage.delete(storageKey);
                jdbcTemplate.update(DELETE_SQL, storageKey);
            } catch (Exception exception) {
                log.error("Failed to clean queued media: {}", storageKey, exception);
            }
        }
    }
}
