package com.formypet.domain.notification.repository.query;

import java.time.LocalDate;

public record RoutineReminderCandidate(long id, long userId, String label, String petName, String repeatType,
                                       String days, String times, int monthlyInterval, LocalDate startDate, LocalDate endDate) {}
