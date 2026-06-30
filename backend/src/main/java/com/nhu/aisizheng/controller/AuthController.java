package com.nhu.aisizheng.controller;

import com.nhu.aisizheng.common.Result;
import com.nhu.aisizheng.common.BusinessException;
import com.nhu.aisizheng.service.AuthService;
import com.nhu.aisizheng.utils.JwtUtils;
import jakarta.servlet.http.HttpServletRequest;
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
    private final JwtUtils jwtUtils;

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

    @PostMapping("/password")
    public Result<Void> changePassword(@RequestBody ChangePasswordRequest req, HttpServletRequest request) {
        authService.changePassword(currentUserId(request), req.oldPassword, req.newPassword);
        return Result.success();
    }

    private Long currentUserId(HttpServletRequest request) {
        String header = request.getHeader("Authorization");
        if (header == null || !header.startsWith("Bearer ")) {
            throw new BusinessException(401, "未登录");
        }
        return jwtUtils.getUserId(header.substring(7));
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

    public record ChangePasswordRequest(
            @NotBlank String oldPassword,
            @NotBlank String newPassword) {}
}
