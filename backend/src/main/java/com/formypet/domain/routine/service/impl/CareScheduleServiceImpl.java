package com.formypet.domain.routine.service.impl;

import com.formypet.common.exception.ForbiddenException;
import com.formypet.common.exception.InvalidInputException;
import com.formypet.common.exception.NotFoundException;
import com.formypet.common.time.UtcTime;
import com.formypet.domain.routine.dto.request.CareScheduleRequest;
import com.formypet.domain.routine.dto.response.CareScheduleResponse;
import com.formypet.domain.routine.entity.CareSchedule;
import com.formypet.domain.routine.repository.CareScheduleRepository;
import com.formypet.domain.routine.repository.query.CareSchedulePetAccessRepository;
import com.formypet.domain.routine.service.CareScheduleService;
import com.formypet.domain.notification.service.NotificationService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.time.LocalTime;
import java.time.format.DateTimeFormatter;
import java.util.List;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class CareScheduleServiceImpl implements CareScheduleService {
    private static final DateTimeFormatter TIME_FORMATTER = DateTimeFormatter.ofPattern("HH:mm");
    private final CareScheduleRepository schedules;
    private final CareSchedulePetAccessRepository access;
    private final NotificationService notificationService;

    @Override @Transactional
    public CareScheduleResponse create(Long actorId, Long petId, CareScheduleRequest request) {
        findVisibleOwnedPet(actorId, petId);
        var schedule = CareSchedule.create(petId, request.categoryId(), request.title(), request.startDate(),
                request.startTime(), request.endDate(), request.endTime(), request.allDay(),
                request.place(), request.memo(), request.reminder());
        schedules.save(schedule);
        schedules.refreshStoredValues(schedule);
        return response(schedule);
    }

    @Override
    public List<CareScheduleResponse> list(Long actorId, Long petId) {
        findVisibleOwnedPet(actorId, petId);
        return schedules.findOrderedByPetId(petId).stream().map(this::response).toList();
    }

    @Override
    public CareScheduleResponse get(Long actorId, Long petId, Long scheduleId) {
        findVisibleOwnedPet(actorId, petId);
        return response(requireSchedule(petId, scheduleId));
    }

    @Override @Transactional
    public CareScheduleResponse update(Long actorId, Long petId, Long scheduleId, CareScheduleRequest request) {
        findVisibleOwnedPet(actorId, petId);
        notificationService.deletePendingReminders("CARE_SCHEDULE", scheduleId);
        var schedule = requireSchedule(petId, scheduleId);
        schedule.update(request.categoryId(), request.title(), request.startDate(), request.startTime(),
                request.endDate(), request.endTime(), request.allDay(), request.place(), request.memo(), request.reminder());
        schedules.refreshStoredValues(schedule);
        return response(schedule);
    }

    @Override @Transactional
    public void delete(Long actorId, Long petId, Long scheduleId) {
        findVisibleOwnedPet(actorId, petId);
        notificationService.deletePendingReminders("CARE_SCHEDULE", scheduleId);
        schedules.delete(requireSchedule(petId, scheduleId));
        schedules.flush();
    }

    private void findVisibleOwnedPet(Long actorId, Long petId) {
        if (!access.userExists(actorId)) throw InvalidInputException.invalidInput();
        var pet = access.findPet(petId)
                .orElseThrow(() -> new NotFoundException("Pet not found.", "PET_NOT_FOUND"));
        if (!pet.userId().equals(actorId)) throw new ForbiddenException("Forbidden pet.", "PET_FORBIDDEN");
        if (pet.deleted()) throw new NotFoundException("Pet not found or deleted.", "PET_NOT_FOUND_OR_DELETED");
    }

    private CareSchedule requireSchedule(Long petId, Long scheduleId) {
        return schedules.findByIdAndPetId(scheduleId, petId)
                .orElseThrow(() -> new NotFoundException("Care schedule not found.", "CARE_SCHEDULE_NOT_FOUND"));
    }

    private CareScheduleResponse response(CareSchedule schedule) {
        return CareScheduleResponse.of(schedule.getId(), schedule.getPetId(), schedule.getCategoryId(),
                schedule.getTitle(), schedule.getStartDate(), formatTime(schedule.getStartTime()),
                schedule.getEndDate(), formatTime(schedule.getEndTime()), schedule.isAllDay(),
                schedule.getPlace(), schedule.getMemo(), schedule.getReminder(), UtcTime.fromDatabase(schedule.getCreatedAt()));
    }

    private static String formatTime(LocalTime time) {
        return time == null ? null : time.format(TIME_FORMATTER);
    }
}
