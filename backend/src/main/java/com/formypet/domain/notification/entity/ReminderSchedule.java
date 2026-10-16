package com.formypet.domain.notification.entity;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Locale;

/** Shared calendar rules for candidate generation and last-moment dispatch checks. */
public final class ReminderSchedule {
    private ReminderSchedule() {}

    public static boolean scheduledOn(String repeat, LocalDate start, LocalDate date,
                                      List<Integer> days, int monthlyInterval) {
        return switch (repeat) {
            case "daily" -> true;
            case "weekly" -> days.contains(day(date.getDayOfWeek()));
            case "biweekly" -> days.contains(day(date.getDayOfWeek()))
                    && ChronoUnit.WEEKS.between(start, date) % 2 == 0;
            case "monthly" -> start.getDayOfMonth() == date.getDayOfMonth()
                    && ChronoUnit.MONTHS.between(start.withDayOfMonth(1), date.withDayOfMonth(1)) % monthlyInterval == 0;
            default -> false;
        };
    }

    public static Long reminderOffset(String reminder) {
        if (reminder == null) return null;
        return switch (reminder.trim().toLowerCase(Locale.ROOT)) {
            case "하루 전", "1 day before" -> 1440L;
            case "2시간 전", "2 hours before" -> 120L;
            case "1시간 전", "1 hour before" -> 60L;
            case "30분 전", "30 minutes before" -> 30L;
            default -> null;
        };
    }

    private static int day(DayOfWeek day) { return day == DayOfWeek.SUNDAY ? 0 : day.getValue(); }
}
