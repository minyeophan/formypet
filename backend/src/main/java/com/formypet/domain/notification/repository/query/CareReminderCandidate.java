package com.formypet.domain.notification.repository.query;

import java.time.LocalDate;
import java.time.LocalTime;

public record CareReminderCandidate(long id, long userId, String title, String petName,
                                    LocalDate startDate, LocalTime startTime, String reminder) {}
