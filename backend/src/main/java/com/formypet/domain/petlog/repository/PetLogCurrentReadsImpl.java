package com.formypet.domain.petlog.repository;

import com.formypet.domain.petlog.entity.PetLog;
import jakarta.persistence.EntityManager;
import jakarta.persistence.LockModeType;
import java.util.Optional;

public class PetLogCurrentReadsImpl implements PetLogCurrentReads {
    private final EntityManager entities;
    public PetLogCurrentReadsImpl(EntityManager entities) { this.entities = entities; }

    public Optional<PetLog> findCurrent(Long id, Long petId) {
        var rows = entities.createNativeQuery("SELECT * FROM pet_logs WHERE id=? AND pet_id=? FOR UPDATE", PetLog.class)
                .setParameter(1, id).setParameter(2, petId).getResultList();
        if (rows.isEmpty()) return Optional.empty();
        var log = (PetLog) rows.getFirst();
        // Native row locks do not replace a stale entity already present in this context.
        entities.refresh(log, LockModeType.PESSIMISTIC_WRITE);
        return Optional.of(log);
    }
}
