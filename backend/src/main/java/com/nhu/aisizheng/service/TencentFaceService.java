package com.nhu.aisizheng.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.nhu.aisizheng.common.BusinessException;
import com.nhu.aisizheng.config.TencentCloudConfig;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Instant;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.HexFormat;
import java.util.Map;

@Slf4j
@Service
@RequiredArgsConstructor
public class TencentFaceService {
    private static final String ENDPOINT = "iai.tencentcloudapi.com";
    private static final String SERVICE = "iai";
    private static final String API_VERSION = "2020-03-03";
    private static final double PASS_SCORE = 85.0;

    private final TencentCloudConfig config;
    private final ObjectMapper objectMapper;
    private final RestTemplate restTemplate = new RestTemplate();

    public boolean isConfigured() {
        return hasText(config.getSecretId())
                && hasText(config.getSecretKey())
                && !config.getSecretId().startsWith("YOUR_")
                && !config.getSecretKey().startsWith("YOUR_");
    }

    public String getFaceGroup() {
        return config.getFaceGroup();
    }

    public boolean ensureGroup() {
        if (!isConfigured()) {
            throw new BusinessException("未配置腾讯云 SecretId/SecretKey，无法使用腾讯云人脸识别");
        }
        try {
            var body = Map.<String, Object>of(
                    "GroupId", config.getFaceGroup(),
                    "GroupName", config.getFaceGroup(),
                    "FaceModelVersion", "3.0"
            );
            JsonNode response = call("CreateGroup", body);
            if (response.path("Error").isMissingNode()) {
                return true;
            }
            String code = response.path("Error").path("Code").asText();
            if (code.contains("ResourceInUse") || code.contains("AlreadyExists")
                    || code.contains("InvalidParameterValue.GroupIdAlreadyExist")) {
                return true;
            }
            log.warn("腾讯云人脸库创建失败: code={}, msg={}",
                    code, response.path("Error").path("Message").asText());
            return false;
        } catch (Exception e) {
            log.warn("腾讯云人脸库创建异常: {}", e.getMessage());
            return false;
        }
    }

    public boolean registerFace(String userId, String imageBase64) {
        ensureGroup();
        try {
            var body = Map.<String, Object>of(
                    "GroupId", config.getFaceGroup(),
                    "PersonName", "user_" + userId,
                    "PersonId", userId,
                    "Gender", 0,
                    "Image", imageBase64,
                    "UniquePersonControl", 4,
                    "QualityControl", 4,
                    "NeedRotateDetection", 1
            );
            JsonNode response = call("CreatePerson", body);
            JsonNode error = response.path("Error");
            if (error.isMissingNode()) {
                log.info("腾讯云人脸注册成功: userId={}", userId);
                return true;
            }
            String code = error.path("Code").asText();
            String message = error.path("Message").asText();
            if (code.contains("ResourceInUse") || code.contains("AlreadyExists")) {
                return addFace(userId, imageBase64);
            }
            log.warn("腾讯云人脸注册失败: userId={}, code={}, msg={}", userId, code, message);
            return false;
        } catch (BusinessException e) {
            throw e;
        } catch (Exception e) {
            log.error("腾讯云人脸注册异常: userId={}", userId, e);
            throw new BusinessException("腾讯云人脸注册失败: " + e.getMessage());
        }
    }

    public FaceRecognitionService.FaceSearchResult verifyLiveFaceAgainstGroup(String imageBase64) {
        if (!isConfigured()) {
            throw new BusinessException("未配置腾讯云 SecretId/SecretKey，无法进行真实人脸验证");
        }
        try {
            var body = Map.<String, Object>of(
                    "GroupIds", new String[]{config.getFaceGroup()},
                    "Image", imageBase64,
                    "MaxPersonNum", 1,
                    "QualityControl", 4,
                    "NeedPersonInfo", 0
            );
            JsonNode response = call("SearchPersons", body);
            JsonNode error = response.path("Error");
            if (!error.isMissingNode()) {
                String msg = error.path("Message").asText(error.path("Code").asText("腾讯云人脸搜索失败"));
                log.warn("腾讯云人脸搜索失败: {}", msg);
                return new FaceRecognitionService.FaceSearchResult(null, 0.0, false, false, msg);
            }
            JsonNode results = response.path("Results");
            if (!results.isArray() || results.isEmpty()) {
                return new FaceRecognitionService.FaceSearchResult(null, 0.0, false, false, "腾讯云未返回可用人脸搜索结果");
            }
            JsonNode candidates = results.get(0).path("Candidates");
            if (!candidates.isArray() || candidates.isEmpty()) {
                return new FaceRecognitionService.FaceSearchResult(null, 0.0, false, false, "未匹配到腾讯云人脸库人员");
            }
            JsonNode top = candidates.get(0);
            String userId = top.path("PersonId").asText(null);
            double score = top.path("Score").asDouble(0.0);
            boolean passed = score >= PASS_SCORE;
            return new FaceRecognitionService.FaceSearchResult(
                    userId,
                    score,
                    passed,
                    true,
                    passed ? "腾讯云人脸比对通过" : "腾讯云人脸相似度不足，需达到 " + PASS_SCORE
            );
        } catch (BusinessException e) {
            throw e;
        } catch (Exception e) {
            log.error("腾讯云人脸搜索异常", e);
            return new FaceRecognitionService.FaceSearchResult(null, 0.0, false, false,
                    "腾讯云人脸识别服务异常: " + e.getMessage());
        }
    }

    public FaceRecognitionService.FaceVerifyResult verifyImageLiveness(String imageBase64) {
        return new FaceRecognitionService.FaceVerifyResult(
                true,
                1.0,
                0,
                "腾讯云当前链路使用 App 端动作采集，后端执行人脸库比对"
        );
    }

    public JsonNode probe() {
        if (!isConfigured()) {
            throw new BusinessException("未配置腾讯云 SecretId/SecretKey");
        }
        return call("GetGroupList", Map.of("Limit", 1, "Offset", 0));
    }

    private boolean addFace(String userId, String imageBase64) {
        var body = Map.<String, Object>of(
                "GroupId", config.getFaceGroup(),
                "PersonId", userId,
                "Images", new String[]{imageBase64},
                "QualityControl", 4,
                "NeedRotateDetection", 1
        );
        JsonNode response = call("CreateFace", body);
        if (response.path("Error").isMissingNode()) {
            log.info("腾讯云追加人脸成功: userId={}", userId);
            return true;
        }
        log.warn("腾讯云追加人脸失败: userId={}, msg={}",
                userId, response.path("Error").path("Message").asText());
        return false;
    }

    private JsonNode call(String action, Object payload) {
        try {
            String body = objectMapper.writeValueAsString(payload);
            HttpHeaders headers = signedHeaders(action, body);
            String raw = restTemplate.postForObject(
                    "https://" + ENDPOINT,
                    new HttpEntity<>(body, headers),
                    String.class
            );
            JsonNode root = objectMapper.readTree(raw);
            return root.path("Response");
        } catch (BusinessException e) {
            throw e;
        } catch (Exception e) {
            throw new BusinessException("腾讯云人脸接口调用失败: " + e.getMessage());
        }
    }

    private HttpHeaders signedHeaders(String action, String payload) throws Exception {
        long timestamp = Instant.now().getEpochSecond();
        String date = DateTimeFormatter.ofPattern("yyyy-MM-dd")
                .withZone(ZoneOffset.UTC)
                .format(Instant.ofEpochSecond(timestamp));

        String canonicalHeaders = "content-type:application/json; charset=utf-8\nhost:" + ENDPOINT + "\n";
        String signedHeaders = "content-type;host";
        String hashedRequestPayload = sha256Hex(payload);
        String canonicalRequest = "POST\n/\n\n" + canonicalHeaders + "\n" + signedHeaders + "\n" + hashedRequestPayload;
        String credentialScope = date + "/" + SERVICE + "/tc3_request";
        String stringToSign = "TC3-HMAC-SHA256\n" + timestamp + "\n" + credentialScope + "\n" + sha256Hex(canonicalRequest);

        byte[] secretDate = hmac256(("TC3" + config.getSecretKey()).getBytes(StandardCharsets.UTF_8), date);
        byte[] secretService = hmac256(secretDate, SERVICE);
        byte[] secretSigning = hmac256(secretService, "tc3_request");
        String signature = HexFormat.of().formatHex(hmac256(secretSigning, stringToSign));

        String authorization = "TC3-HMAC-SHA256 "
                + "Credential=" + config.getSecretId() + "/" + credentialScope + ", "
                + "SignedHeaders=" + signedHeaders + ", "
                + "Signature=" + signature;

        HttpHeaders headers = new HttpHeaders();
        headers.set("Content-Type", "application/json; charset=utf-8");
        headers.set("Host", ENDPOINT);
        headers.set("Authorization", authorization);
        headers.set("X-TC-Action", action);
        headers.set("X-TC-Timestamp", String.valueOf(timestamp));
        headers.set("X-TC-Version", API_VERSION);
        headers.set("X-TC-Region", config.getRegion());
        return headers;
    }

    private static String sha256Hex(String value) throws Exception {
        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        return HexFormat.of().formatHex(digest.digest(value.getBytes(StandardCharsets.UTF_8)));
    }

    private static byte[] hmac256(byte[] key, String value) throws Exception {
        Mac mac = Mac.getInstance("HmacSHA256");
        mac.init(new SecretKeySpec(key, "HmacSHA256"));
        return mac.doFinal(value.getBytes(StandardCharsets.UTF_8));
    }

    private static boolean hasText(String value) {
        return value != null && !value.isBlank();
    }
}
