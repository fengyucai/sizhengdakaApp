package com.nhu.aisizheng.service;

import com.nhu.aisizheng.common.BusinessException;
import com.nhu.aisizheng.model.User;
import com.nhu.aisizheng.repository.UserRepository;
import com.nhu.aisizheng.utils.JwtUtils;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.util.Map;

/**
 * 认证服务
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtUtils jwtUtils;

    /**
     * 账号密码登录
     */
    public Map<String, String> login(String studentId, String rawPassword) {
        User user = userRepository.findByStudentIdAndStatus(studentId, "ACTIVE")
                .orElseThrow(() -> new BusinessException("账号不存在或已停用"));

        if (!passwordEncoder.matches(rawPassword, user.getPasswordHash())) {
            throw new BusinessException("密码错误");
        }

        String accessToken = jwtUtils.generateAccessToken(user.getId(), user.getRole());
        String refreshToken = jwtUtils.generateRefreshToken(user.getId(), user.getRole());

        return Map.of(
                "accessToken", accessToken,
                "refreshToken", refreshToken,
                "userId", String.valueOf(user.getId()),
                "realName", user.getRealName(),
                "role", user.getRole()
        );
    }

    /**
     * 用户自主注册 (默认STUDENT角色)
     */
    public Map<String, String> register(String studentId, String realName,
                                         String rawPassword, String phone) {
        if (userRepository.existsByStudentId(studentId)) {
            throw new BusinessException("该学号已被注册");
        }

        User user = User.builder()
                .studentId(studentId)
                .realName(realName)
                .passwordHash(passwordEncoder.encode(rawPassword))
                .role("STUDENT")
                .phone(phone)
                .faceRegistered(false)
                .status("ACTIVE")
                .build();

        userRepository.save(user);
        log.info("新用户注册: {} {}", studentId, realName);

        // 注册后自动登录
        String accessToken = jwtUtils.generateAccessToken(user.getId(), user.getRole());
        String refreshToken = jwtUtils.generateRefreshToken(user.getId(), user.getRole());

        return Map.of(
                "accessToken", accessToken,
                "refreshToken", refreshToken,
                "userId", String.valueOf(user.getId()),
                "realName", user.getRealName(),
                "role", user.getRole(),
                "message", "注册成功，请尽快完成人脸录入"
        );
    }

    /**
     * 刷新Token
     */
    public String refreshAccessToken(String refreshToken) {
        if (!jwtUtils.validateToken(refreshToken)) {
            throw new BusinessException(401, "RefreshToken无效或已过期");
        }
        Long userId = jwtUtils.getUserId(refreshToken);
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new BusinessException("用户不存在"));
        return jwtUtils.generateAccessToken(user.getId(), user.getRole());
    }

    /**
     * 注册人脸（标记）
     */
    public void registerFace(Long userId, String faceGroupId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new BusinessException("用户不存在"));
        user.setFaceRegistered(true);
        user.setFaceGroupId(faceGroupId);
        userRepository.save(user);
    }
}
