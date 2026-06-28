package com.nhu.aisizheng.controller;

import com.nhu.aisizheng.common.BusinessException;
import com.nhu.aisizheng.common.Result;
import com.nhu.aisizheng.model.User;
import com.nhu.aisizheng.repository.UserRepository;
import com.nhu.aisizheng.service.BaiduFaceService;
import com.nhu.aisizheng.service.MockFaceService;
import com.nhu.aisizheng.service.StorageService;
import com.nhu.aisizheng.utils.JwtUtils;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.Base64;
import java.util.List;
import java.util.Map;

/**
 * 人脸识别接口
 */
@Slf4j
@RestController
@RequestMapping("/face")
@RequiredArgsConstructor
public class FaceController {

    private final BaiduFaceService baiduFaceService;
    private final MockFaceService mockFaceService;
    private final UserRepository userRepository;
    private final StorageService storageService;
    private final JwtUtils jwtUtils;

    /**
     * 人脸注册 — 上传3张照片
     * 前端: 分别拍摄正面/微左/微右三角度照片
     */
    @PostMapping("/register")
    public Result<Map<String, Object>> registerFace(
            @RequestParam("images") List<MultipartFile> images,
            HttpServletRequest request) throws IOException {

        Long userId = getUserId(request);
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new BusinessException("用户不存在"));

        if (images.size() < 3) {
            return Result.fail("请上传3张不同角度的人脸照片 (正面/微左/微右)");
        }

        int successCount = 0;
        for (MultipartFile image : images) {
            // 压缩图片后转BASE64
            byte[] bytes = image.getBytes();
            String base64 = Base64.getEncoder().encodeToString(bytes);

            if (baiduFaceService.isConfigured()) {
                // 百度AI注册
                boolean ok = baiduFaceService.registerFace(
                        String.valueOf(user.getId()), base64, "dorm_checkin");
                if (ok) successCount++;
            } else {
                // Mock注册
                mockFaceService.registerFace(String.valueOf(user.getId()), base64);
                successCount++;
            }

            // 原图存MinIO (7天后清理策略由定时任务处理)
            try {
                storageService.upload(bytes, "face/" + userId,
                        "register_" + System.currentTimeMillis() + ".jpg", "image/jpeg");
            } catch (Exception e) {
                log.warn("MinIO存储失败(不影响注册): {}", e.getMessage());
            }
        }

        // 仅当至少1张照片注册成功时才标记人脸已注册
        if (successCount > 0) {
            user.setFaceRegistered(true);
            userRepository.save(user);
        }

        return Result.success(Map.of(
                "successCount", successCount,
                "totalImages", images.size(),
                "userId", userId,
                "message", "人脸注册完成: " + successCount + "/" + images.size() + " 张成功"
        ));
    }

    /**
     * 人脸验证 — 单张实时照片比对
     */
    @PostMapping("/verify")
    public Result<Map<String, Object>> verifyFace(
            @RequestParam("image") MultipartFile image) throws IOException {

        String base64 = Base64.getEncoder().encodeToString(image.getBytes());

        BaiduFaceService.FaceSearchResult result;
        if (baiduFaceService.isConfigured()) {
            result = baiduFaceService.searchFace(base64, "dorm_checkin");
        } else {
            result = mockFaceService.searchFace(base64, "dorm_checkin");
        }

        return Result.success(Map.of(
                "matchedUserId", result.userId() != null ? result.userId() : "NONE",
                "score", result.score(),
                "passed", result.passed(),
                "livenessPassed", result.livenessPassed(),
                "message", result.message()
        ));
    }

    /**
     * 检查人脸注册状态
     */
    @GetMapping("/status")
    public Result<Map<String, Object>> faceStatus(HttpServletRequest request) {
        Long userId = getUserId(request);
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new BusinessException("用户不存在"));

        return Result.success(Map.of(
                "faceRegistered", user.getFaceRegistered(),
                "userId", userId,
                "realName", user.getRealName()
        ));
    }

    private Long getUserId(HttpServletRequest request) {
        String token = request.getHeader("Authorization").replace("Bearer ", "");
        return jwtUtils.getUserId(token);
    }
}
