package com.formypet.domain.media.repository;

import com.formypet.domain.media.entity.MediaResource;
import com.formypet.domain.media.repository.query.MediaFile;
import com.formypet.domain.media.repository.query.MediaLocation;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;

public interface MediaResourceRepository extends JpaRepository<MediaResource, Long> {
    @Query("select new com.formypet.domain.media.repository.query.MediaFile(m.id, m.storageKey, m.fileSize) "
            + "from MediaResource m where m.id=:id and m.userId=:userId")
    Optional<MediaFile> ownedFile(Long id, Long userId);

    @Query("select new com.formypet.domain.media.repository.query.MediaFile(m.id, m.storageKey, m.fileSize) "
            + "from MediaResource m where m.id=:id and m.userId=:userId and m.petId is null and m.recordId is null")
    Optional<MediaFile> profileFile(Long id, Long userId);

    @Query("select new com.formypet.domain.media.repository.query.MediaLocation(m.storageKey, m.contentType) "
            + "from MediaResource m where m.id=:id and m.userId=:userId "
            + "and m.mediaKind in ('PET_LOG_DRAFT','PET_LOG') and m.status='STORED'")
    Optional<MediaLocation> petLogLocation(Long id, Long userId);

    @Modifying(flushAutomatically = true)
    @Query("delete from MediaResource m where m.userId=:userId and m.recordId=:recordId")
    int deleteRecord(Long userId, Long recordId);

    @Modifying(flushAutomatically = true)
    @Query("delete from MediaResource m where m.id = :id and m.userId = :userId")
    int deleteOwned(Long id, Long userId);
}
