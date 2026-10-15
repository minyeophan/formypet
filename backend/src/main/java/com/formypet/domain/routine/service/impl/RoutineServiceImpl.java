package com.formypet.domain.routine.service.impl;

import com.formypet.auth.repository.UserRepository;
import com.formypet.common.exception.InvalidInputException;
import com.formypet.common.time.UtcTime;
import com.formypet.config.NotificationProperties;
import com.formypet.domain.pet.entity.Pet;
import com.formypet.domain.pet.repository.PetRepository;
import com.formypet.domain.routine.dto.request.*;
import com.formypet.domain.routine.dto.response.*;
import com.formypet.domain.routine.entity.Routine;
import com.formypet.domain.routine.entity.RoutineCompletion;
import com.formypet.domain.routine.repository.RoutineRepository;
import com.formypet.domain.routine.repository.RoutineCompletionRepository;
import com.formypet.domain.routine.repository.query.RoutineActivityTypeRepository;
import com.formypet.domain.routine.service.RoutineService;
import com.formypet.notification.NotificationService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class RoutineServiceImpl implements RoutineService {
    private final RoutineRepository routines;
    private final RoutineCompletionRepository completions;
    private final RoutineActivityTypeRepository activityTypes;
    private final PetRepository petRepository;
    private final UserRepository userRepository;
    private final NotificationService notificationService;
    private final NotificationProperties notificationProperties;

    @Override @Transactional
    public RoutineResponse create(Long actorId, Long petId, RoutineCreateRequest request) {
        Pet pet = findOwnedPet(actorId, petId);
        Routine.validateLabel(request.label());
        validateActivityType(request.typeId());
        var routine = Routine.create(pet.getId(), request.label(), request.typeId(), request.repeatType(),
                request.days(), request.monthlyInterval(), request.startDate(), request.endDate(), request.times(),
                request.note(), request.detail(), request.notificationEnabled());
        routines.saveAndFlush(routine);
        return response(routine);
    }

    @Override
    public List<RoutineResponse> list(Long actorId, Long petId) {
        Pet pet = findOwnedPet(actorId, petId);
        return routines.findByPetIdOrderByIdDesc(pet.getId()).stream().map(this::response).toList();
    }

    @Override @Transactional
    public RoutineResponse update(Long actorId, Long petId, Long routineId, RoutineUpdateRequest request) {
        Pet pet = findOwnedPet(actorId, petId);
        var routine = requireRoutine(pet.getId(), routineId);
        notificationService.deletePendingReminders("ROUTINE", routineId);
        Routine.validateLabel(request.label() != null ? request.label() : routine.getLabel());
        validateActivityType(request.typeId() != null ? request.typeId() : routine.getTypeId());
        routine.update(request.label(), request.typeId(), request.repeatType(), request.days(), request.monthlyInterval(),
                request.startDate(), request.endDate(), request.times(), request.note(), request.detail(),
                request.active(), request.notificationEnabled(), request.clearEndDate());
        routines.flush();
        return response(routine);
    }

    @Override @Transactional
    public RoutineCompletionResponse markCompletion(Long actorId, Long petId, Long routineId, LocalDate date,
                                                     RoutineCompletionRequest request) {
        Pet pet = findOwnedPet(actorId, petId);
        requireRoutine(pet.getId(), routineId);
        String status = RoutineCompletion.normalizeStatus(request.status());
        var completedAt = "COMPLETED".equals(status) ? UtcTime.toDatabase(Instant.now()) : null;
        completions.mark(routineId, pet.getId(), date, status, completedAt,
                UtcTime.toDatabase(Instant.now()), UtcTime.toDatabase(Instant.now()));
        return completionResponse(routineId, date);
    }

    @Override @Transactional
    public TodayRoutineResponse today(Long actorId, Long petId, LocalDate date) {
        Pet pet = findOwnedPet(actorId, petId);
        LocalDate target = date != null ? date : LocalDate.now(notificationProperties.timezone());
        var scheduled = routines.findByPetIdOrderByIdDesc(pet.getId()).stream()
                .filter(routine -> routine.isScheduledOn(target)).toList();
        var items = new ArrayList<TodayRoutineResponse.TodayRoutineItem>();
        int done = 0;
        for (var routine : scheduled) {
            completions.ensurePending(routine.getId(), pet.getId(), target,
                    UtcTime.toDatabase(Instant.now()), UtcTime.toDatabase(Instant.now()));
            var completion = completionResponse(routine.getId(), target);
            if ("COMPLETED".equals(completion.status())) done++;
            items.add(TodayRoutineResponse.TodayRoutineItem.of(response(routine), completion));
        }
        return TodayRoutineResponse.of(items, TodayRoutineResponse.Summary.of(items.size(), done));
    }

    @Override @Transactional
    public void delete(Long actorId, Long petId, Long routineId) {
        Pet pet = findOwnedPet(actorId, petId);
        var routine = requireRoutine(pet.getId(), routineId);
        notificationService.deletePendingReminders("ROUTINE", routineId);
        routines.delete(routine);
        routines.flush();
    }

    private Routine requireRoutine(Long petId, Long routineId) {
        return routines.findByIdAndPetId(routineId, petId)
                .orElseThrow(() -> new IllegalArgumentException("Routine not found."));
    }

    private Pet findOwnedPet(Long actorId, Long petId) {
        var user = userRepository.findById(actorId).orElseThrow(() -> new IllegalStateException("User not found."));
        if (petId == null) throw new IllegalArgumentException("Pet id must not be null.");
        return petRepository.findById(petId).filter(pet -> pet.isOwnedBy(user.getId()))
                .orElseThrow(() -> new AccessDeniedException("No access to this pet."));
    }

    private void validateActivityType(String typeId) {
        if (!activityTypes.exists(typeId)) throw new InvalidInputException("Unsupported activity type.", "INVALID_INPUT");
    }

    private RoutineResponse response(Routine r) {
        return RoutineResponse.of(r.getId(), r.getPetId(), r.getLabel(), r.getTypeId(), r.getRepeatType(),
                r.getDays(), r.getMonthlyInterval(), r.getStartDate(), r.getEndDate(), r.getTimes(),
                r.getNote(), r.getDetail(), r.isActive(), r.isNotificationEnabled());
    }

    private RoutineCompletionResponse completionResponse(Long routineId, LocalDate date) {
        var c = completions.findByRoutineIdAndScheduledDate(routineId, date)
                .orElseThrow(() -> new org.springframework.dao.EmptyResultDataAccessException(1));
        return RoutineCompletionResponse.of(c.getId(), c.getRoutineId(), c.getPetId(), c.getScheduledDate(),
                c.getStatus(), UtcTime.fromDatabase(c.getCompletedAt()));
    }
}
