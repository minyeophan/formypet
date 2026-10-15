package com.formypet.domain.record.repository;

import com.formypet.domain.record.entity.ActivityRecord;
import java.time.LocalDate;
import java.util.List;

public interface ActivityRecordQueries {
    List<ActivityRecord> findRecords(Long petId, LocalDate date, String typeId, Integer limit);
    void refreshStoredValues(ActivityRecord record);
}
