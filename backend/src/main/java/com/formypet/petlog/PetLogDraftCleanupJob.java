package com.formypet.petlog;

import com.formypet.media.MediaService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
@Slf4j
public class PetLogDraftCleanupJob {
    private final MediaService media;

    @Scheduled(fixedDelayString="${app.pet-log.draft-cleanup-interval-ms:3600000}")
    public void cleanup() {
        try {
            int removed=media.cleanupExpiredPetLogDrafts();
            if(removed>0) log.info("Expired {} pet log draft photos",removed);
        } catch(RuntimeException e) {
            log.warn("Pet log draft cleanup will retry on the next scheduled run",e);
        }
    }
}
