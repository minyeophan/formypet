package com.formypet.domain.record.repository;

import com.formypet.domain.record.entity.ActivityRecord;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;

public interface ActivityRecordRepository extends JpaRepository<ActivityRecord, Long>, ActivityRecordQueries {
    Optional<ActivityRecord> findByIdAndPetId(Long id, Long petId);
}
