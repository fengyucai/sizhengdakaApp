package com.nhu.aisizheng.common;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 统一API响应封装
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class Result<T> {

    private int code;
    private String message;
    private T data;
    private long timestamp;

    public static <T> Result<T> success(T data) {
        return new Result<>(200, "success", data, System.currentTimeMillis() / 1000);
    }

    public static <T> Result<T> success() {
        return success(null);
    }

    public static <T> Result<T> fail(int code, String message) {
        return new Result<>(code, message, null, System.currentTimeMillis() / 1000);
    }

    public static <T> Result<T> fail(String message) {
        return fail(400, message);
    }

    public static <T> Result<T> unauthorized(String message) {
        return fail(401, message);
    }

    public static <T> Result<T> forbidden(String message) {
        return fail(403, message);
    }
}
