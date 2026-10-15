package com.formypet.domain.routine.repository;

import com.formypet.domain.routine.entity.CareSchedule;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.List;
import java.util.Optional;

public interface CareScheduleRepository extends JpaRepository<CareSchedule, Long>, CareScheduleRefresh {
    Optional<CareSchedule> findByIdAndPetId(Long id, Long petId);

    @Query("select c from CareSchedule c where c.petId = :petId order by c.startDate, "
            + "case when c.startTime is null then 1 else 0 end, c.startTime, c.id")
    List<CareSchedule> findOrderedByPetId(@Param("petId") Long petId);
}
