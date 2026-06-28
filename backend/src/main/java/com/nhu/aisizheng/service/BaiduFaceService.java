package com.nhu.aisizheng.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.nhu.aisizheng.config.BaiduAiConfig;
import com.nhu.aisizheng.common.BusinessException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.util.Base64;
import java.util.Map;

/**
 * 百度AI人脸识别服务
 *
 * 文档: https://cloud.baidu.com/doc/FACE/s/37jwvz4ix
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class BaiduFaceService {

    private final BaiduAiConfig config;
    private final ObjectMapper objectMapper;
    private final RestTemplate restTemplate = new RestTemplate();

    private String cachedToken;
    private long tokenExpireTime;

    // ==================== Token管理 ====================

    /** 获取AccessToken (缓存2小时) */
    public String getAccessToken() {
        if (cachedToken != null && System.currentTimeMillis() < tokenExpireTime) {
            return cachedToken;
        }
        try {
            String url = "https://aip.baidubce.com/oauth/2.0/token"
                    + "?grant_type=client_credentials"
                    + "&client_id=" + config.getApiKey()
                    + "&client_secret=" + config.getSecretKey();

            String resp = restTemplate.getForObject(url, String.class);
            JsonNode node = objectMapper.readTree(resp);

            if (node.has("error")) {
                throw new BusinessException("百度AI认证失败: " + node.path("error_description").asText());
            }

            cachedToken = node.path("access_token").asText();
            tokenExpireTime = System.currentTimeMillis() + node.path("expires_in").asLong() * 1000 - 60000;
            log.info("百度AI AccessToken获取成功, 有效期{}秒", node.path("expires_in").asLong());
            return cachedToken;
        } catch (BusinessException e) { throw e; }
        catch (Exception e) {
            log.error("获取百度AI Token失败", e);
            throw new BusinessException("百度AI服务不可用: " + e.getMessage());
        }
    }

    /** 是否已配置百度AI */
    public boolean isConfigured() {
        return config.getApiKey() != null && !config.getApiKey().isBlank()
                && !config.getApiKey().startsWith("YOUR_");
    }

    // ==================== 人脸注册 ====================

    /**
     * 注册人脸 — 将用户照片加入人脸库
     * @param userId   用户ID (学号)
     * @param imageBase64 人脸照片BASE64 (注册时用高质量正面照)
     * @param faceGroup 人脸库分组
     */
    public boolean registerFace(String userId, String imageBase64, String faceGroup) {
        try {
            String url = "https://aip.baidubce.com/rest/2.0/face/v3/faceset/user/add"
                    + "?access_token=" + getAccessToken();

            Map<String, Object> body = Map.of(
                    "image", imageBase64,
                    "image_type", "BASE64",
                    "group_id", faceGroup,
                    "user_id", userId,
                    "quality_control", "HIGH",
                    "liveness_control", "NONE"   // 注册时不需活体
            );

            String resp = restTemplate.postForObject(url, objectMapper.writeValueAsString(body), String.class);
            JsonNode node = objectMapper.readTree(resp);

            int errorCode = node.path("error_code").asInt();
            if (errorCode == 0 || errorCode == 223102) { // 0=成功, 223102=人脸已存在
                log.info("人脸注册成功: userId={},  errorCode={}", userId, errorCode);
                return true;
            }
            log.warn("人脸注册失败: userId={}, errorCode={}, msg={}", userId, errorCode, node.path("error_msg").asText());
            return false;
        } catch (BusinessException e) { throw e; }
        catch (Exception e) {
            log.error("人脸注册异常: userId={}", userId, e);
            throw new BusinessException("人脸注册失败: " + e.getMessage());
        }
    }

    // ==================== 人脸搜索 (1:N 打卡验证) ====================

    /**
     * 人脸搜索 — 在指定分组中搜索匹配的人脸
     * @return FaceSearchResult (userId + score)
     */
    public FaceSearchResult searchFace(String imageBase64, String faceGroup) {
        try {
            String url = "https://aip.baidubce.com/rest/2.0/face/v3/search"
                    + "?access_token=" + getAccessToken();

            Map<String, Object> body = Map.of(
                    "image", imageBase64,
                    "image_type", "BASE64",
                    "group_id_list", faceGroup,
                    "quality_control", "HIGH",
                    "liveness_control", "HIGH",   // 打卡时要求活体
                    "max_user_num", 1
            );

            String resp = restTemplate.postForObject(url, objectMapper.writeValueAsString(body), String.class);
            JsonNode node = objectMapper.readTree(resp);

            int errorCode = node.path("error_code").asInt();
            if (errorCode != 0) {
                String msg = node.path("error_msg").asText();
                log.warn("人脸搜索失败: errorCode={}, msg={}", errorCode, msg);
                return new FaceSearchResult(null, 0.0, false, false, msg);
            }

            JsonNode userList = node.path("result").path("user_list");
            if (userList.isEmpty()) {
                return new FaceSearchResult(null, 0.0, false, false, "未匹配到注册人脸");
            }

            JsonNode top = userList.get(0);
            String userId = top.path("user_id").asText();
            double score = top.path("score").asDouble();
            boolean passed = score >= 85.0; // 阈值85%

            // 活体检测结果
            JsonNode liveness = node.path("result").path("face_list").get(0).path("liveness");
            double livemapScore = liveness.path("livemap_score").asDouble(0.0);
            boolean livenessPassed = livemapScore > 0.8;

            log.info("人脸搜索: userId={}, score={}, 人脸通过:{}, 活体通过:{}", userId, score, passed, livenessPassed);

            return new FaceSearchResult(userId, score, passed, livenessPassed,
                    passed ? "人脸验证通过" : "人脸相似度不足(需≥85%)");
        } catch (BusinessException e) { throw e; }
        catch (Exception e) {
            log.error("人脸搜索异常", e);
            return new FaceSearchResult(null, 0.0, false, false, "人脸识别服务异常");
        }
    }

    // ==================== 结果对象 ====================

    public record FaceSearchResult(
            String userId,
            Double score,
            Boolean passed,
            Boolean livenessPassed,
            String message
    ) {}
}
