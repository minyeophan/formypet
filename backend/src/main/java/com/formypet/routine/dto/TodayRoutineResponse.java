package com.formypet.routine.dto;

import java.util.List;

public record TodayRoutineResponse(List<TodayRoutineItem> routines, Summary summary) {

    public static TodayRoutineResponse of(List<TodayRoutineItem> routines, Summary summary) {
        return new TodayRoutineResponse(routines, summary);
    }

    public record TodayRoutineItem(RoutineResponse routine, RoutineCompletionResponse completion) {
        public static TodayRoutineItem of(RoutineResponse routine, RoutineCompletionResponse completion) {
            return new TodayRoutineItem(routine, completion);
        }
    }

    public record Summary(int total, int done, double rate) {
        public static Summary of(int total, int done) {
            double rate = total == 0 ? 0.0 : Math.round((done * 1000.0) / total) / 10.0;
            return new Summary(total, done, rate);
        }
    }
}
