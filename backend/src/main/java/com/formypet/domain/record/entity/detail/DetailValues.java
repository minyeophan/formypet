package com.formypet.domain.record.entity.detail;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Map;

/** Preserve the existing detail conversion contract without depending on HTTP DTOs. */
final class DetailValues {
    private DetailValues() {}
    static String text(Map<String, Object> values, String key) {
        Object value = values.get(key);
        return value == null ? null : value.toString();
    }
    static BigDecimal decimal(Map<String, Object> values, String key) {
        Object value = values.get(key);
        return value == null ? null : new BigDecimal(value.toString());
    }
    static Integer integer(Map<String, Object> values, String key) {
        Object value = values.get(key);
        return value == null ? null : ((Number) value).intValue();
    }
    static LocalDate date(Map<String, Object> values, String key) {
        Object value = values.get(key);
        return value == null ? null : LocalDate.parse(value.toString());
    }
}
