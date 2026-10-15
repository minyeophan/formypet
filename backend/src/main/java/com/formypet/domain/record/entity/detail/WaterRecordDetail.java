package com.formypet.domain.record.entity.detail;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.NoArgsConstructor;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.Map;

@Entity
@Table(name = "record_water")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class WaterRecordDetail extends RecordDetail {
    @Column(name = "amount", precision = 7, scale = 2)
    private BigDecimal amount;

    public static WaterRecordDetail from(Long recordId, Map<String, Object> values) {
        var detail = new WaterRecordDetail();
        detail.recordId = recordId;
        detail.amount = DetailValues.decimal(values, "amount");
        return detail;
    }

    @Override
    public Map<String, Object> toMap() {
        Map<String, Object> values = new LinkedHashMap<>();
        values.put("amount", amount);
        return values;
    }
}
