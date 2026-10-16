package com.formypet.domain.petlog.repository;

import com.formypet.domain.petlog.entity.PetLog;
import java.util.Optional;

public interface PetLogCurrentReads {
    Optional<PetLog> findCurrent(Long id, Long petId);
}
