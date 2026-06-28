package com.nhu.aisizheng.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * 开发模式Mock人脸服务
 * 当百度AI未配置时使用，模拟人脸注册和验证流程
 */
@Slf4j
@Service
public class MockFaceService {

    /** 已注册人脸的用户集合 */
    private final Map<String, String> registeredFaces = new ConcurrentHashMap<>();

    /** 注册人脸 (模拟) */
    public boolean registerFace(String userId, String imageBase64) {
        registeredFaces.put(userId, imageBase64.substring(0, Math.min(50, imageBase64.length()))); // 只存摘要
        log.info("[Mock] 人脸注册成功: userId={}", userId);
        return true;
    }

    /** 人脸搜索 (模拟 — 返回96%相似度) */
    public BaiduFaceService.FaceSearchResult searchFace(String imageBase64, String faceGroup) {
        // 模拟: 始终返回高相似度+活体通过
        log.info("[Mock] 人脸搜索: group={}, imageSize={}bytes", faceGroup, imageBase64.length());

        // 模拟活体检测: BASE64长度太短说明是照片攻击
        boolean livenessPassed = imageBase64.length() > 1000;

        return new BaiduFaceService.FaceSearchResult(
                "MOCK_USER", 96.5, true, livenessPassed, "Mock人脸验证通过 (开发模式)"
        );
    }

    /** 是否已注册 */
    public boolean isRegistered(String userId) {
        return registeredFaces.containsKey(userId);
    }
}
