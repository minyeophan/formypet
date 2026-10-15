package com.formypet.domain.record.repository;

import com.formypet.domain.record.entity.ActivityRecord;
import com.formypet.domain.record.entity.detail.*;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import org.springframework.stereotype.Repository;
import java.util.*;
import java.util.stream.Collectors;

@Repository
public class RecordDetailRepository {
    @PersistenceContext private EntityManager entityManager;

    public void replace(RecordDetail detail) {
        if (detail == null) return;
        // Merge copies every mapped column, including nulls: detail updates replace, not patch.
        RecordDetail stored = entityManager.merge(detail);
        entityManager.flush();
        entityManager.refresh(stored);
    }

    public Map<Long, Map<String, Object>> findDetails(List<ActivityRecord> records) {
        Map<Long, Map<String, Object>> result = new HashMap<>();
        var grouped = records.stream().collect(Collectors.groupingBy(ActivityRecord::getTypeId));
        grouped.forEach((type, group) -> {
            Class<? extends RecordDetail> entityType = detailClass(type);
            if (entityType == null) return;
            List<Long> ids = group.stream().map(ActivityRecord::getId).toList();
            for (int offset = 0; offset < ids.size(); offset += 500) {
                var batch = ids.subList(offset, Math.min(offset + 500, ids.size()));
                entityManager.createQuery("select d from " + entityType.getSimpleName()
                                + " d where d.recordId in :ids", entityType)
                        .setParameter("ids", batch).getResultList()
                        .forEach(detail -> result.put(detail.getRecordId(), detail.toMap()));
            }
        });
        return result;
    }

    private Class<? extends RecordDetail> detailClass(String type) {
        return switch (type) {
            case "meal" -> MealRecordDetail.class;
            case "water" -> WaterRecordDetail.class;
            case "medicine" -> MedicineRecordDetail.class;
            case "poop" -> PoopRecordDetail.class;
            case "walk" -> WalkRecordDetail.class;
            case "weight" -> WeightRecordDetail.class;
            case "vet" -> VetRecordDetail.class;
            case "diary", "etc" -> null;
            default -> throw new IllegalArgumentException("지원하지 않는 기록 타입입니다.");
        };
    }
}
