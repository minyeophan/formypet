package com.formypet.domain.record.entity.detail;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.NoArgsConstructor;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.Map;

@Entity
@Table(name = "record_meal")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class MealRecordDetail extends RecordDetail {
    @Column(name = "food_type", length = 30)
    private String foodType;
    @Column(name = "feeding_method", length = 30)
    private String feedingMethod;
    @Column(name = "served_amount", precision = 7, scale = 2)
    private BigDecimal servedAmount;
    @Column(name = "consumed_amount", precision = 7, scale = 2)
    private BigDecimal consumedAmount;
    @Column(name = "consumed_percent", precision = 5, scale = 2)
    private BigDecimal consumedPercent;
    @Column(name = "brand", length = 100)
    private String brand;
    @Column(name = "product", length = 100)
    private String product;
    @Column(name = "ingredients", columnDefinition = "TEXT")
    private String ingredients;

    public static MealRecordDetail from(Long recordId, Map<String, Object> values) {
        var detail = new MealRecordDetail();
        detail.recordId = recordId;
        detail.foodType = DetailValues.text(values, "foodType");
        detail.feedingMethod = DetailValues.text(values, "feedingMethod");
        detail.servedAmount = DetailValues.decimal(values, "servedAmount");
        detail.consumedAmount = DetailValues.decimal(values, "consumedAmount");
        detail.consumedPercent = DetailValues.decimal(values, "consumedPercent");
        detail.brand = DetailValues.text(values, "brand");
        detail.product = DetailValues.text(values, "product");
        detail.ingredients = DetailValues.text(values, "ingredients");
        return detail;
    }

    @Override
    public Map<String, Object> toMap() {
        Map<String, Object> values = new LinkedHashMap<>();
        values.put("foodType", foodType);
        values.put("feedingMethod", feedingMethod);
        values.put("servedAmount", servedAmount);
        values.put("consumedAmount", consumedAmount);
        values.put("consumedPercent", consumedPercent);
        values.put("brand", brand);
        values.put("product", product);
        values.put("ingredients", ingredients);
        return values;
    }
}
