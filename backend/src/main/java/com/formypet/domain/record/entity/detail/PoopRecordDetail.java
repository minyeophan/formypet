package com.formypet.domain.record.entity.detail;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.NoArgsConstructor;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.Map;

@Entity
@Table(name = "record_poop")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class PoopRecordDetail extends RecordDetail {
    @Column(name = "poop_shape", length = 30)
    private String poopShape;
    @Column(name = "poop_color", length = 30)
    private String poopColor;
    @Column(name = "poop_amount", length = 30)
    private String poopAmount;
    @Column(name = "poop_smell", length = 30)
    private String poopSmell;

    public static PoopRecordDetail from(Long recordId, Map<String, Object> values) {
        var detail = new PoopRecordDetail();
        detail.recordId = recordId;
        detail.poopShape = DetailValues.text(values, "poopShape");
        detail.poopColor = DetailValues.text(values, "poopColor");
        detail.poopAmount = DetailValues.text(values, "poopAmount");
        detail.poopSmell = DetailValues.text(values, "poopSmell");
        return detail;
    }

    @Override
    public Map<String, Object> toMap() {
        Map<String, Object> values = new LinkedHashMap<>();
        values.put("poopShape", poopShape);
        values.put("poopColor", poopColor);
        values.put("poopAmount", poopAmount);
        values.put("poopSmell", poopSmell);
        return values;
    }
}
