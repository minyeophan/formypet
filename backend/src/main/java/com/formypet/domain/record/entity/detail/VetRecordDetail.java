package com.formypet.domain.record.entity.detail;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.NoArgsConstructor;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.Map;

@Entity
@Table(name = "record_vet")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class VetRecordDetail extends RecordDetail {
    @Column(name = "vet_clinic_name", length = 100)
    private String vetClinicName;
    @Column(name = "vet_visit_reason", length = 30)
    private String vetVisitReason;
    @Column(name = "vet_diagnosis", columnDefinition = "TEXT")
    private String vetDiagnosis;
    @Column(name = "vet_treatment", columnDefinition = "TEXT")
    private String vetTreatment;
    @Column(name = "vet_cost")
    private Integer vetCost;
    @Column(name = "vet_next_visit_date")
    private LocalDate vetNextVisitDate;

    public static VetRecordDetail from(Long recordId, Map<String, Object> values) {
        var detail = new VetRecordDetail();
        detail.recordId = recordId;
        detail.vetClinicName = DetailValues.text(values, "vetClinicName");
        detail.vetVisitReason = DetailValues.text(values, "vetVisitReason");
        detail.vetDiagnosis = DetailValues.text(values, "vetDiagnosis");
        detail.vetTreatment = DetailValues.text(values, "vetTreatment");
        detail.vetCost = DetailValues.integer(values, "vetCost");
        detail.vetNextVisitDate = DetailValues.date(values, "vetNextVisitDate");
        return detail;
    }

    @Override
    public Map<String, Object> toMap() {
        Map<String, Object> values = new LinkedHashMap<>();
        values.put("vetClinicName", vetClinicName);
        values.put("vetVisitReason", vetVisitReason);
        values.put("vetDiagnosis", vetDiagnosis);
        values.put("vetTreatment", vetTreatment);
        values.put("vetCost", vetCost);
        values.put("vetNextVisitDate", vetNextVisitDate);
        return values;
    }
}
