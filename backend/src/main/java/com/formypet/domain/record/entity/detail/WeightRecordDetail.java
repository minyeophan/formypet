package com.formypet.domain.record.entity.detail;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.NoArgsConstructor;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.Map;

@Entity
@Table(name = "record_weight")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class WeightRecordDetail extends RecordDetail {
    @Column(name = "weight", precision = 5, scale = 2)
    private BigDecimal weight;

    public static WeightRecordDetail from(Long recordId, Map<String, Object> values) {
        var detail = new WeightRecordDetail();
        detail.recordId = recordId;
        detail.weight = DetailValues.decimal(values, "weight");
        return detail;
    }

    @Override
    public Map<String, Object> toMap() {
        Map<String, Object> values = new LinkedHashMap<>();
        values.put("weight", weight);
        return values;
    }
}
