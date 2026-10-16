package com.formypet.domain.record.entity.detail;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.NoArgsConstructor;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.Map;

@Entity
@Table(name = "record_medicine")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class MedicineRecordDetail extends RecordDetail {
    @Column(name = "medicine_name", length = 100)
    private String medicineName;
    @Column(name = "ingredients", length = 200)
    private String ingredients;
    @Column(name = "dosage", length = 100)
    private String dosage;

    public static MedicineRecordDetail from(Long recordId, Map<String, Object> values) {
        var detail = new MedicineRecordDetail();
        detail.recordId = recordId;
        detail.medicineName = DetailValues.text(values, "medicineName");
        detail.ingredients = DetailValues.text(values, "ingredients");
        detail.dosage = DetailValues.text(values, "dosage");
        return detail;
    }

    @Override
    public Map<String, Object> toMap() {
        Map<String, Object> values = new LinkedHashMap<>();
        values.put("medicineName", medicineName);
        values.put("ingredients", ingredients);
        values.put("dosage", dosage);
        return values;
    }
}
