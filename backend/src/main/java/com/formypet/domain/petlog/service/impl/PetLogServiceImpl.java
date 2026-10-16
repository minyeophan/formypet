package com.formypet.domain.petlog.service.impl;

import com.formypet.domain.petlog.service.PetLogService;
import com.formypet.domain.petlog.dto.request.PetLogCreateRequest;
import com.formypet.domain.petlog.dto.request.PetLogUpdateRequest;
import com.formypet.domain.petlog.dto.response.PetLogResponse;
import com.formypet.domain.petlog.dto.response.PetLogPageResponse;
import com.formypet.domain.petlog.dto.response.PetLogPhotoResponse;

import com.formypet.domain.user.entity.User;
import com.formypet.domain.user.repository.UserRepository;
import com.formypet.global.exception.NotFoundException;
import com.formypet.global.exception.ApiException;
import com.formypet.domain.petlog.entity.PetLog;
import com.formypet.domain.petlog.repository.*;
import com.formypet.domain.media.service.MediaService;
import com.formypet.domain.pet.entity.Pet;
import com.formypet.domain.pet.repository.PetRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.*;
import java.util.*;

@Service
@RequiredArgsConstructor
public class PetLogServiceImpl implements PetLogService {
    private final PetLogRepository logs;
    private final PetLogQueryRepository queries;
    private final PetLogPhotoRepository photos;
    private final PetLogPreferenceRepository preferences;
    private final PetRepository pets;
    private final UserRepository users;
    private final MediaService media;

    @Transactional
    public PetLogResponse create(Long userId, Long petId, PetLogCreateRequest request) {
        media.lockPetLogMediaOwner(userId);
        Pet pet = owned(userId, petId);
        LocalDateTime entryAt = LocalDateTime.of(request.date(), request.time());
        long id = logs.saveAndFlush(PetLog.create(userId, pet.getId(), entryAt, request.note())).getId();
        attachPhotos(userId, petId, id, request.mediaIds());
        preferences.dismiss(userId, petId, Instant.now());
        return get(userId, petId, id);
    }

    @Transactional(readOnly = true)
    public PetLogPageResponse list(Long userId, Long petId, Integer year, Integer month, int limit, String cursor) {
        owned(userId, petId);
        if (limit < 1 || limit > 50) throw new IllegalArgumentException("limit은 1~50이어야 합니다.");
        if (year != null && (year < 1 || year > 9998)) throw new IllegalArgumentException("연도를 확인해 주세요.");
        if (month != null && (year == null || month < 1 || month > 12)) throw new IllegalArgumentException("월 조회에는 올바른 연도가 필요합니다.");
        LocalDateTime from = year == null ? null : LocalDate.of(year, month == null ? 1 : month, 1).atStartOfDay();
        LocalDateTime to = year == null ? null : month == null ? from.plusYears(1) : from.plusMonths(1);
        LocalDateTime before = null;
        Long beforeId = null;
        if (cursor != null && !cursor.isBlank()) {
            String decoded;
            try { decoded = new String(java.util.Base64.getUrlDecoder().decode(cursor), java.nio.charset.StandardCharsets.UTF_8); }
            catch (IllegalArgumentException e) { throw new IllegalArgumentException("페이지 커서가 올바르지 않습니다."); }
            String[] parts = decoded.split("\\|", -1);
            if (parts.length != 2) throw new IllegalArgumentException("페이지 커서가 올바르지 않습니다.");
            try { before=LocalDateTime.parse(parts[0]); beforeId=Long.parseLong(parts[1]); }
            catch (RuntimeException e) { throw new IllegalArgumentException("페이지 커서가 올바르지 않습니다."); }
        }
        List<PetLogResponse> found = queries.list(petId, from, to, before, beforeId, limit + 1).stream()
                .map(this::response).toList();
        boolean more=found.size()>limit;
        if (more) found=found.subList(0,limit);
        String next=null;
        if(more&&!found.isEmpty()) { PetLogResponse last=found.getLast(); LocalDateTime at=LocalDateTime.of(last.date(),last.time()); next=java.util.Base64.getUrlEncoder().withoutPadding().encodeToString((at+"|"+last.id()).getBytes(java.nio.charset.StandardCharsets.UTF_8)); }
        return new PetLogPageResponse(List.copyOf(found), next, queries.years(petId), queries.hasAny(petId));
    }

    @Transactional(readOnly = true)
    public PetLogResponse get(Long userId, Long petId, Long id) {
        owned(userId, petId);
        return response(queries.find(id, petId).orElseThrow(() -> new NotFoundException("Pet log not found.", "PET_LOG_NOT_FOUND")));
    }

    @Transactional
    public PetLogResponse update(Long userId, Long petId, Long id, PetLogUpdateRequest request) {
        if (request.version() < 0) throw new IllegalArgumentException("기록 버전이 올바르지 않습니다.");
        media.lockPetLogMediaOwner(userId);
        owned(userId, petId);
        var log = logs.findCurrent(id, petId).orElseThrow(this::conflict);
        if (!log.hasVersion(request.version())) throw conflict();
        log.revise(LocalDateTime.of(request.date(), request.time()), request.note(), Instant.now());
        logs.flush();
        attachPhotos(userId, petId, id, request.mediaIds());
        return get(userId, petId, id);
    }

    @Transactional
    public void delete(Long userId, Long petId, Long id, long expectedVersion) {
        media.lockPetLogMediaOwner(userId);
        owned(userId, petId);
        var log = logs.findCurrent(id, petId).orElseThrow(() -> new NotFoundException("Pet log not found.", "PET_LOG_NOT_FOUND"));
        if (!log.hasVersion(expectedVersion)) {
            throw conflict();
        }
        media.deletePetLogMedia(userId, id);
        logs.delete(log);
        logs.flush();
    }

    private ApiException conflict() {
        return new ApiException(org.springframework.http.HttpStatus.CONFLICT, "pet-log-conflict",
                "Pet log changed", "기록이 다른 곳에서 변경되었어요.", "PET_LOG_CONFLICT");
    }

    @Transactional
    public boolean dismissExample(Long userId, Long petId) {
        owned(userId, petId);
        preferences.dismiss(userId, petId);
        return true;
    }

    @Transactional(readOnly=true)
    public boolean exampleDismissed(Long userId,Long petId){
        owned(userId,petId);
        return preferences.isDismissed(userId, petId);
    }

    private void attachPhotos(Long userId, Long petId, Long logId, List<Long> ids) {
        List<Long> oldIds = photos.lockMediaIds(logId);
        for(Long mediaId:ids) {
            boolean draft = photos.promoteDraft(mediaId, userId, petId);
            if(!draft && !oldIds.contains(mediaId)) throw new AccessDeniedException("사진을 이 기록에 첨부할 수 없습니다.");
        }
        photos.deleteLinks(logId);
        for(int position=0;position<ids.size();position++) {
            int[] dimensions=media.imageDimensions(userId,ids.get(position));
            photos.link(ids.get(position), logId, position, dimensions[0], dimensions[1]);
        }
        List<Long> removed=oldIds.stream().filter(id->!ids.contains(id)).toList();
        media.deletePetLogMediaIds(userId,removed);
    }
    private PetLogResponse response(PetLogQueryRepository.LogRow row) {
        var attachments = photos.find(row.id()).stream().map(photo -> new PetLogPhotoResponse(photo.id(),
                "/api/v1/media/" + photo.id(), photo.position(), photo.width(), photo.height())).toList();
        return new PetLogResponse(row.id(), row.petId(), row.entryAt().toLocalDate(), row.entryAt().toLocalTime(),
                row.note(), row.version(), attachments, row.createdAt(), null);
    }
    private Pet owned(Long userId,Long petId){ User user=users.findById(userId).orElseThrow(); return pets.findById(petId).filter(p->p.isOwnedBy(user.getId())).orElseThrow(()->new AccessDeniedException("Cannot access this pet.")); }
}
