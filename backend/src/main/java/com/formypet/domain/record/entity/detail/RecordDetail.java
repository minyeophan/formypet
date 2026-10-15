package com.formypet.domain.record.entity.detail;

import jakarta.persistence.*;
import lombok.Getter;
import java.util.Map;

@MappedSuperclass
@Getter
public abstract class RecordDetail {
    @Id @Column(name = "record_id")
    protected Long recordId;
    public abstract Map<String, Object> toMap();

    public static RecordDetail from(Long recordId, String typeId, Map<String, Object> values) {
        Map<String, Object> fields = values == null ? Map.of() : values;
        return switch (typeId) {
            case "meal" -> MealRecordDetail.from(recordId, fields);
            case "water" -> WaterRecordDetail.from(recordId, fields);
            case "medicine" -> MedicineRecordDetail.from(recordId, fields);
            case "poop" -> PoopRecordDetail.from(recordId, fields);
            case "walk" -> WalkRecordDetail.from(recordId, fields);
            case "weight" -> WeightRecordDetail.from(recordId, fields);
            case "vet" -> VetRecordDetail.from(recordId, fields);
            case "diary", "etc" -> null;
            default -> throw new IllegalArgumentException("지원하지 않는 기록 타입입니다.");
        };
    }
}
