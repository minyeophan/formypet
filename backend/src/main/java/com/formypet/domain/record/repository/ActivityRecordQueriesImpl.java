package com.formypet.domain.record.repository;

import com.formypet.domain.record.entity.ActivityRecord;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import java.time.LocalDate;
import java.util.List;

public class ActivityRecordQueriesImpl implements ActivityRecordQueries {
    @PersistenceContext private EntityManager entityManager;

    @Override
    public List<ActivityRecord> findRecords(Long petId, LocalDate date, String typeId, Integer limit) {
        String jpql = "select r from ActivityRecord r where r.petId = :petId";
        if (date != null) jpql += " and r.date = :date";
        boolean filterType = typeId != null && !typeId.isBlank();
        if (filterType) jpql += " and r.typeId = :typeId";
        jpql += " order by r.date desc, r.id desc";
        var query = entityManager.createQuery(jpql, ActivityRecord.class).setParameter("petId", petId);
        if (date != null) query.setParameter("date", date);
        if (filterType) query.setParameter("typeId", typeId);
        if (limit != null) query.setMaxResults(limit);
        return query.getResultList();
    }

    @Override
    public void refreshStoredValues(ActivityRecord record) {
        entityManager.flush();
        entityManager.refresh(record);
    }
}
