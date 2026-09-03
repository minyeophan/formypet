package com.formypet.common.response;

public record ApiResponse<T>(T data, String message) {

    public static <T> ApiResponse<T> of(T data) {
        return new ApiResponse<>(data, "success");
    }

    public static <T> ApiResponse<T> of(T data, String message) {
        return new ApiResponse<>(data, message);
    }

    public static ApiResponse<Void> empty() {
        return new ApiResponse<>(null, "success");
    }
}
