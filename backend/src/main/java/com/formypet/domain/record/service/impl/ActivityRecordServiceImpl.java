package com.formypet.domain.record.service.impl;

import com.formypet.auth.repository.UserRepository;
import com.formypet.common.exception.NotFoundException;
import com.formypet.domain.pet.entity.Pet;
import com.formypet.domain.pet.repository.PetRepository;
import com.formypet.domain.record.dto.request.ActivityRecordCreateRequest;
import com.formypet.domain.record.dto.request.ActivityRecordUpdateRequest;
import com.formypet.domain.record.dto.response.ActivityRecordResponse;
import com.formypet.domain.record.entity.ActivityRecord;
import com.formypet.domain.record.entity.detail.RecordDetail;
import com.formypet.domain.record.repository.*;
import com.formypet.domain.record.service.ActivityRecordService;
import com.formypet.domain.routine.repository.RoutineRepository;
import com.formypet.domain.media.service.MediaService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class ActivityRecordServiceImpl implements ActivityRecordService {
    private final ActivityRecordRepository records;
    private final RecordDetailRepository details;
    private final RecordMediaQueryRepository mediaQueries;
    private final PetRepository petRepository;
    private final UserRepository userRepository;
    private final RoutineRepository routines;
    private final MediaService mediaService;

    @Override
    @Transactional
    public ActivityRecordResponse create(Long actorId, Long petId, ActivityRecordCreateRequest request) {
        Pet pet = findOwnedPet(actorId, petId);
        ActivityRecord.validateType(request.typeId());
        validateRoutineBelongsToPet(pet.getId(), request.routineId());
        var record = records.saveAndFlush(ActivityRecord.create(pet.getId(), request.typeId(), request.date(),
                request.time(), request.routineId(), request.note()));
        details.replace(RecordDetail.from(record.getId(), record.getTypeId(), request.detail()));
        records.refreshStoredValues(record);
        return responses(List.of(record)).getFirst();
    }

    @Override
    @Transactional(readOnly = true)
    public List<ActivityRecordResponse> list(Long actorId, Long petId, LocalDate date, String typeId, Integer limit) {
        Pet pet = findOwnedPet(actorId, petId);
        if (typeId != null && !typeId.isBlank()) ActivityRecord.validateType(typeId);
        return responses(records.findRecords(pet.getId(), date, typeId, limit));
    }

    @Override
    @Transactional(readOnly = true)
    public ActivityRecordResponse get(Long actorId, Long petId, Long recordId) {
        Pet pet = findOwnedPet(actorId, petId);
        return responses(List.of(findRecord(pet.getId(), recordId))).getFirst();
    }

    @Override
    @Transactional
    public ActivityRecordResponse update(Long actorId, Long petId, Long recordId, ActivityRecordUpdateRequest request) {
        Pet pet = findOwnedPet(actorId, petId);
        var record = findRecord(pet.getId(), recordId);
        validateRoutineBelongsToPet(pet.getId(), request.routineId());
        record.update(request.date(), request.time(), request.routineId(), request.note());
        if (request.detail() != null)
            details.replace(RecordDetail.from(recordId, record.getTypeId(), request.detail()));
        records.refreshStoredValues(record);
        return responses(List.of(record)).getFirst();
    }

    @Override
    @Transactional
    public void delete(Long actorId, Long petId, Long recordId) {
        Pet pet = findOwnedPet(actorId, petId);
        var record = findRecord(pet.getId(), recordId);
        mediaService.deleteRecordMedia(actorId, recordId);
        records.delete(record);
        records.flush();
    }

    private List<ActivityRecordResponse> responses(List<ActivityRecord> rows) {
        if (rows.isEmpty()) return List.of();
        var detailValues = details.findDetails(rows);
        var mediaUrls = mediaQueries.findMediaUrls(rows.stream().map(ActivityRecord::getId).toList());
        return rows.stream().map(record -> ActivityRecordResponse.of(record.getId(), record.getPetId(),
                record.getTypeId(), record.getDate(), record.getTime(), record.getRoutineId(), record.getNote(),
                mediaUrls.getOrDefault(record.getId(), List.of()),
                detailValues.getOrDefault(record.getId(), Map.of()))).toList();
    }

    private ActivityRecord findRecord(Long petId, Long recordId) {
        return records.findByIdAndPetId(recordId, petId)
                .orElseThrow(() -> new NotFoundException("Activity record not found.", "ACTIVITY_RECORD_NOT_FOUND"));
    }

    private Pet findOwnedPet(Long actorId, Long petId) {
        var user = userRepository.findById(actorId)
                .orElseThrow(() -> new IllegalStateException("사용자를 찾을 수 없습니다."));
        if (petId == null) throw new IllegalArgumentException("Pet id must not be null.");
        return petRepository.findById(petId).filter(pet -> pet.isOwnedBy(user.getId()))
                .orElseThrow(() -> new AccessDeniedException("해당 펫에 접근할 권한이 없습니다."));
    }

    private void validateRoutineBelongsToPet(Long petId, Long routineId) {
        if (routineId == null) return;
        var routine = routines.findById(routineId)
                .orElseThrow(() -> new IllegalArgumentException("Routine not found."));
        if (!routine.getPetId().equals(petId))
            throw new AccessDeniedException("Cannot attach routine from another pet.");
    }
}
