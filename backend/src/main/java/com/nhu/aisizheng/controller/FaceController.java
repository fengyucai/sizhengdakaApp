package com.nhu.aisizheng.controller;

import com.nhu.aisizheng.common.BusinessException;
import com.nhu.aisizheng.common.Result;
import com.nhu.aisizheng.model.User;
import com.nhu.aisizheng.repository.UserRepository;
import com.nhu.aisizheng.service.FaceRecognitionService;
import com.nhu.aisizheng.service.StorageService;
import com.nhu.aisizheng.service.TencentFaceService;
import com.nhu.aisizheng.utils.JwtUtils;
import io.swagger.v3.oas.annotations.tags.Tag;
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
@Tag(name = "人脸识别", description = "人脸注册、核验、活体动作探测和服务状态")
public class FaceController {

    private final FaceRecognitionService faceRecognitionService;
    private final TencentFaceService tencentFaceService;
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
        int liveCount = 0;
        for (MultipartFile image : images) {
            // 压缩图片后转BASE64
            byte[] bytes = image.getBytes();
            String base64 = Base64.getEncoder().encodeToString(bytes);

            if (!faceRecognitionService.isConfigured()) {
                throw new BusinessException("未配置人脸识别服务密钥，无法进行真实人脸注册");
            }
            FaceRecognitionService.FaceVerifyResult liveness =
                    faceRecognitionService.verifyImageLiveness(base64);
            if (!Boolean.TRUE.equals(liveness.livenessPassed())) {
                log.warn("人脸注册活体检测未通过: userId={}, errorCode={}, msg={}",
                        userId, liveness.errorCode(), liveness.message());
                continue;
            }
            liveCount++;
            boolean ok = faceRecognitionService.registerFace(String.valueOf(user.getId()), base64);
            if (ok) successCount++;

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
                "liveCount", liveCount,
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

        if (!faceRecognitionService.isConfigured()) {
            throw new BusinessException("未配置人脸识别服务密钥，无法进行真实人脸验证");
        }
        FaceRecognitionService.FaceSearchResult result =
                faceRecognitionService.verifyLiveFaceAgainstGroup(base64);

        return Result.success(Map.of(
                "matchedUserId", result.userId() != null ? result.userId() : "NONE",
                "score", result.score(),
                "passed", result.passed(),
                "livenessPassed", result.livenessPassed(),
                "message", result.message()
        ));
    }

    /**
     * 在线图片活体探测。用于联调百度Key是否具备真实活体接口能力。
     * 注意：该接口不是动作式动态活体，仅用于验证百度在线活体接口权限。
     */
    @PostMapping("/liveness/probe")
    public Result<Map<String, Object>> probeLiveness(
            @RequestParam("image") MultipartFile image) throws IOException {

        if (!faceRecognitionService.isConfigured()) {
            return Result.fail("未配置人脸识别服务密钥，无法进行真实活体检测");
        }

        String base64 = Base64.getEncoder().encodeToString(image.getBytes());
        FaceRecognitionService.FaceVerifyResult result =
                faceRecognitionService.verifyImageLiveness(base64);
        return Result.success(Map.of(
                "provider", faceRecognitionService.getProviderName(),
                "mode", faceRecognitionService.getLivenessMode(),
                "livenessPassed", result.livenessPassed(),
                "livenessScore", result.livenessScore(),
                "errorCode", result.errorCode(),
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
                "realName", user.getRealName(),
                "provider", faceRecognitionService.isConfigured()
                        ? faceRecognitionService.getProviderName()
                        : "UNCONFIGURED",
                "faceGroup", faceRecognitionService.getFaceGroup(),
                "livenessMode", faceRecognitionService.isConfigured()
                        ? faceRecognitionService.getLivenessMode()
                        : "UNAVAILABLE",
                "dynamicLivenessReady", faceRecognitionService.isDynamicLivenessReady()
        ));
    }

    @GetMapping("/provider/status")
    public Result<Map<String, Object>> providerStatus() {
        Map<String, Object> data = new java.util.LinkedHashMap<>();
        data.put("provider", faceRecognitionService.getProviderName());
        data.put("configured", faceRecognitionService.isConfigured());
        data.put("faceGroup", faceRecognitionService.getFaceGroup());
        data.put("livenessMode", faceRecognitionService.getLivenessMode());
        data.put("dynamicLivenessReady", faceRecognitionService.isDynamicLivenessReady());
        if ("TENCENT".equals(faceRecognitionService.getProviderName())
                && faceRecognitionService.isConfigured()) {
            try {
                data.put("tencentProbe", tencentFaceService.probe());
                data.put("tencentGroupReady", tencentFaceService.ensureGroup());
            } catch (Exception e) {
                data.put("tencentProbeError", e.getMessage());
            }
        }
        return Result.success(data);
    }

    private Long getUserId(HttpServletRequest request) {
        String token = request.getHeader("Authorization").replace("Bearer ", "");
        return jwtUtils.getUserId(token);
    }
}
