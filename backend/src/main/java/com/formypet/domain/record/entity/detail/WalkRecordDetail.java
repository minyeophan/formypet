package com.formypet.domain.record.entity.detail;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.NoArgsConstructor;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.Map;

@Entity
@Table(name = "record_walk")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class WalkRecordDetail extends RecordDetail {
    @Column(name = "distance", precision = 8, scale = 2)
    private BigDecimal distance;
    @Column(name = "duration")
    private Integer duration;

    public static WalkRecordDetail from(Long recordId, Map<String, Object> values) {
        var detail = new WalkRecordDetail();
        detail.recordId = recordId;
        detail.distance = DetailValues.decimal(values, "distance");
        detail.duration = DetailValues.integer(values, "duration");
        return detail;
    }

    @Override
    public Map<String, Object> toMap() {
        Map<String, Object> values = new LinkedHashMap<>();
        values.put("distance", distance);
        values.put("duration", duration);
        return values;
    }
}
