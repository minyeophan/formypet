package com.formypet.domain.routine.repository;

import com.formypet.domain.routine.entity.CareSchedule;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;

/** Preserve database defaults and TIME(0) normalization in mutation responses. */
public class CareScheduleRefreshImpl implements CareScheduleRefresh {
    @PersistenceContext private EntityManager entityManager;

    @Override
    public void refreshStoredValues(CareSchedule schedule) {
        entityManager.flush();
        entityManager.refresh(schedule);
    }
}
