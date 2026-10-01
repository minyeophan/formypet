package com.formypet.media;

import com.formypet.media.storage.MediaStorage;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.scheduling.annotation.Scheduled;

import java.util.List;
import java.util.concurrent.atomic.AtomicBoolean;

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
    private final AtomicBoolean running = new AtomicBoolean();

    @Override
    public void run(ApplicationArguments args) {
        cleanPending();
    }

    @Scheduled(fixedDelayString = "${app.media.cleanup-interval-ms:30000}")
    public void cleanPending() {
        if (!running.compareAndSet(false, true)) return;
        try {
            cleanClaimedSnapshot();
        } finally {
            running.set(false);
        }
    }

    private void cleanClaimedSnapshot() {
        List<String> storageKeys;
        try {
            storageKeys = jdbcTemplate.queryForList(SELECT_SQL, String.class);
        } catch (RuntimeException exception) {
            log.error("Failed to read media cleanup queue; startup will continue ({})", exception.getClass().getSimpleName());
            return;
        }

        for (String storageKey : storageKeys) {
            try {
                mediaStorage.delete(storageKey);
                jdbcTemplate.update(DELETE_SQL, storageKey);
            } catch (Exception exception) {
                log.error("Failed to clean queued media. It will be retried ({})", exception.getClass().getSimpleName());
            }
        }
    }
}
