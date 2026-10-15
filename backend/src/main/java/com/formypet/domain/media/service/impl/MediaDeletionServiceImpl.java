package com.formypet.domain.media.service.impl;

import com.formypet.domain.media.repository.MediaResourceRepository;
import com.formypet.domain.media.repository.jdbc.MediaQuotaRepository;
import com.formypet.domain.media.repository.jdbc.MediaWorkRepository;
import com.formypet.domain.media.repository.jdbc.MediaAttachmentRepository;
import com.formypet.domain.media.repository.query.MediaFile;
import com.formypet.domain.pet.entity.Pet;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

import com.formypet.domain.media.service.MediaDeletionService;

@Service
@RequiredArgsConstructor
public class MediaDeletionServiceImpl implements MediaDeletionService {
    private final MediaAttachmentRepository attachments;
    private final MediaResourceRepository mediaRepository;
    private final MediaQuotaRepository quotaRepository;
    private final MediaWorkRepository workRepository;

    @Transactional
    public void deleteUserProfileMedia(Long userId, Long mediaId) {
        deleteProfileMedia(userId, mediaId, true);
    }

    @Transactional
    public void deleteReplacedUserProfileMedia(Long userId, Long mediaId) {
        deleteProfileMedia(userId, mediaId, false);
    }

    private void deleteProfileMedia(Long userId, Long mediaId, boolean updateQuota) {
        var media = mediaRepository.profileFile(mediaId, userId).orElse(null);
        if (media == null) return;
        workRepository.enqueue(media.storageKey());
        int deleted = mediaRepository.deleteOwned(mediaId, userId);
        if (deleted == 1 && updateQuota) decrementQuota(userId, media.fileSize(), 1);
    }

    @Transactional
    public void deleteCommunityMedia(Long userId, Long mediaId) {
        deleteOwnedMedia(userId, mediaId);
    }

    @Transactional
    public void deleteRecordMedia(Long userId, Long recordId) {
        // Serialize record-media cleanup with quota reservations and other media deletes for this user.
        if (!quotaRepository.lockOwner(userId)) return;
        var rows = attachments.lockRecord(userId, recordId);
        if (rows.isEmpty()) return;
        int deleted = mediaRepository.deleteRecord(userId, recordId);
        if (deleted != rows.size()) {
            throw new IllegalStateException("Record media changed during deletion.");
        }
        for (var row : rows) {
            workRepository.enqueue(row.storageKey());
        }
        long bytes = rows.stream().mapToLong(MediaFile::fileSize).sum();
        decrementQuota(userId, bytes, deleted);
    }

    @Transactional
    public void deletePetLogMedia(Long userId, Long petLogId) {
        if (!quotaRepository.lockOwner(userId)) return;
        var rows = attachments.lockPetLog(userId, petLogId);
        if (rows.isEmpty()) return;
        deletePetLogMediaRows(userId, rows);
    }

    @Transactional
    public void lockPetLogMediaOwner(Long userId) {
        if (!quotaRepository.lockOwner(userId)) throw new IllegalStateException("Media owner no longer exists.");
    }

    @Transactional
    public void deletePetLogMediaIds(Long userId, java.util.List<Long> mediaIds) {
        if (mediaIds.isEmpty()) return;
        if (!quotaRepository.lockOwner(userId)) return;
        var rows = attachments.lockPetLogIds(userId, mediaIds);
        if (!rows.isEmpty()) deletePetLogMediaRows(userId, rows);
    }

    @Transactional
    public void deletePetLogDataForPet(Long userId, Long petId) {
        if (!quotaRepository.lockOwner(userId)) return;
        var rows = attachments.lockPetLogFilesForPet(userId, petId);
        attachments.deletePetLogData(userId, petId);
        if(rows.isEmpty()) return;
        for(var row:rows) workRepository.enqueue(row.storageKey());
        int deleted = attachments.deletePetLogFilesForPet(userId, petId);
        if(deleted!=rows.size()) throw new IllegalStateException("Pet log media changed during pet deletion.");
        long bytes = rows.stream().mapToLong(MediaFile::fileSize).sum();
        decrementQuota(userId,bytes,deleted);
    }

    @Transactional
    public int cleanupExpiredPetLogDrafts() {
        List<Long> userIds = attachments.expiredDraftOwners();
        int total=0;
        for(Long userId:userIds) {
            if (!quotaRepository.lockOwner(userId)) continue;
            var rows = attachments.lockExpiredDrafts(userId);
            if(rows.isEmpty()) continue;
            for(var row:rows) workRepository.enqueue(row.storageKey());
            int deleted = attachments.deleteExpiredDrafts(userId);
            if(deleted!=rows.size()) throw new IllegalStateException("Expired pet log drafts changed during cleanup.");
            long bytes = rows.stream().mapToLong(MediaFile::fileSize).sum();
            decrementQuota(userId,bytes,deleted);
            total+=deleted;
        }
        return total;
    }

    private void deletePetLogMediaRows(Long userId, List<MediaFile> rows) {
        for (var row: rows) workRepository.enqueue(row.storageKey());
        int deleted = attachments.deletePetLogIds(userId, rows.stream().map(MediaFile::id).toList());
        if (deleted != rows.size()) throw new IllegalStateException("Pet log media changed during deletion.");
        long bytes = rows.stream().mapToLong(MediaFile::fileSize).sum();
        decrementQuota(userId,bytes,deleted);
    }

    private void decrementQuota(Long userId, long bytes, int items) {
        quotaRepository.decrement(userId, bytes, items);
    }

    private void deleteOwnedMedia(Long userId, Long mediaId) {
        var media = mediaRepository.ownedFile(mediaId, userId).orElse(null);
        if (media == null) return;
        workRepository.enqueue(media.storageKey());
        int deleted = mediaRepository.deleteOwned(mediaId, userId);
        if (deleted == 1) decrementQuota(userId, media.fileSize(), 1);
    }
}
