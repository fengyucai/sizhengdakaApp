package com.nhu.aisizheng.controller;

import com.nhu.aisizheng.common.Result;
import com.nhu.aisizheng.service.AuthService;
import jakarta.validation.constraints.NotBlank;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

/**
 * 认证接口
 */
@RestController
@RequestMapping("/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;

    @PostMapping("/login")
    public Result<Map<String, String>> login(@RequestBody LoginRequest req) {
        return Result.success(authService.login(req.studentId, req.password));
    }

    @PostMapping("/register")
    public Result<Map<String, String>> register(@RequestBody RegisterRequest req) {
        return Result.success(authService.register(
                req.studentId, req.realName, req.password, req.phone));
    }

    @PostMapping("/refresh")
    public Result<Map<String, String>> refresh(@RequestBody RefreshRequest req) {
        String newToken = authService.refreshAccessToken(req.refreshToken);
        return Result.success(Map.of("accessToken", newToken));
    }

    // --- Request DTOs ---

    public record LoginRequest(
            @NotBlank String studentId,
            @NotBlank String password) {}

    public record RegisterRequest(
            @NotBlank String studentId,
            @NotBlank String realName,
            @NotBlank String password,
            String phone) {}

    public record RefreshRequest(
            @NotBlank String refreshToken) {}
}
