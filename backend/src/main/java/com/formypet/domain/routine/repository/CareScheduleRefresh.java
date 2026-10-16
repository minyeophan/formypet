package com.formypet.domain.routine.repository;

import com.formypet.domain.routine.entity.CareSchedule;

public interface CareScheduleRefresh {
    void refreshStoredValues(CareSchedule schedule);
}
