package com.formypet.domain.routine.repository;

import com.formypet.domain.routine.entity.RoutineCompletion;
import org.springframework.data.jpa.repository.JpaRepository;
import java.time.LocalDate;
import java.util.Optional;

public interface RoutineCompletionRepository extends JpaRepository<RoutineCompletion, Long>, RoutineCompletionAtomic {
    Optional<RoutineCompletion> findByRoutineIdAndScheduledDate(Long routineId, LocalDate date);
}
