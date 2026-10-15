package com.formypet.domain.routine.repository;

import com.formypet.domain.routine.entity.Routine;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
import java.util.Optional;

public interface RoutineRepository extends JpaRepository<Routine, Long> {
    List<Routine> findByPetIdOrderByIdDesc(Long petId);
    Optional<Routine> findByIdAndPetId(Long id, Long petId);
}
