package com.formypet.domain.record.entity;

import com.formypet.domain.record.entity.detail.*;
import org.junit.jupiter.api.Test;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Map;
import static org.assertj.core.api.Assertions.*;

class RecordDetailTest {
    @Test
    void mealPreservesStringsConvertsDecimalStringsAndIncludesNullColumns() {
        var detail = MealRecordDetail.from(1L, Map.of("foodType", " dry ", "servedAmount", "120.50", "ignored", 1));
        assertThat(detail.getRecordId()).isEqualTo(1L);
        assertThat(detail.toMap()).hasSize(8).containsEntry("foodType", " dry ")
                .containsEntry("servedAmount", new BigDecimal("120.50"))
                .containsEntry("brand", null).doesNotContainKey("ignored");
        assertThat(MealRecordDetail.from(1L, Map.of()).toMap().values()).containsOnlyNulls();
    }

    @Test
    void eachDetailUsesItsExistingKeysAndConversions() {
        assertThat(WaterRecordDetail.from(2L, Map.of("amount", 250)).toMap())
                .containsExactlyInAnyOrderEntriesOf(Map.of("amount", new BigDecimal("250")));
        assertThat(MedicineRecordDetail.from(3L, Map.of("medicineName", 123, "dosage", "1 pill")).toMap())
                .hasSize(3).containsEntry("medicineName", "123").containsEntry("dosage", "1 pill").containsEntry("ingredients", null);
        assertThat(PoopRecordDetail.from(4L, Map.of("poopColor", "brown")).toMap())
                .hasSize(4).containsEntry("poopColor", "brown").containsEntry("poopShape", null);
        assertThat(WalkRecordDetail.from(5L, Map.of("distance", "1.25", "duration", 30.9, "startLat", 37)).toMap())
                .containsExactlyInAnyOrderEntriesOf(Map.of("distance", new BigDecimal("1.25"), "duration", 30));
        assertThat(WeightRecordDetail.from(6L, Map.of("weight", "5.20")).toMap())
                .containsEntry("weight", new BigDecimal("5.20"));
        assertThat(VetRecordDetail.from(7L, Map.of("vetCost", 12000.9, "vetNextVisitDate", "2026-12-31", "clinicLng", 127)).toMap())
                .hasSize(6).containsEntry("vetCost", 12000).containsEntry("vetNextVisitDate", LocalDate.of(2026, 12, 31))
                .doesNotContainKey("clinicLng");
    }

    @Test
    void malformedValuesAreNotSilentlyCoercedToNull() {
        assertThatThrownBy(() -> WaterRecordDetail.from(1L, Map.of("amount", "bad"))).isInstanceOf(NumberFormatException.class);
        assertThatThrownBy(() -> WalkRecordDetail.from(1L, Map.of("duration", "30"))).isInstanceOf(ClassCastException.class);
        assertThatThrownBy(() -> VetRecordDetail.from(1L, Map.of("vetNextVisitDate", "bad")))
                .isInstanceOf(java.time.format.DateTimeParseException.class);
    }
}
