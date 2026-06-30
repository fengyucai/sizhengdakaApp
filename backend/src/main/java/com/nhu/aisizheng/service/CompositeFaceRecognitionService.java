package com.nhu.aisizheng.service;

import com.nhu.aisizheng.config.FaceProviderConfig;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class CompositeFaceRecognitionService implements FaceRecognitionService {
    private final FaceProviderConfig providerConfig;
    private final BaiduFaceService baiduFaceService;
    private final TencentFaceService tencentFaceService;

    @Override
    public boolean isConfigured() {
        return switchProvider().isConfigured();
    }

    @Override
    public String getProviderName() {
        return activeProvider();
    }

    @Override
    public String getFaceGroup() {
        return switchProvider().getFaceGroup();
    }

    @Override
    public String getLivenessMode() {
        return "TENCENT".equals(activeProvider())
                ? "APP_ACTION_CAPTURE_AND_CLOUD_MATCH"
                : "IMAGE_LIVENESS";
    }

    @Override
    public boolean isDynamicLivenessReady() {
        return false;
    }

    @Override
    public boolean registerFace(String userId, String imageBase64) {
        return switchProvider().registerFace(userId, imageBase64);
    }

    @Override
    public FaceSearchResult verifyLiveFaceAgainstGroup(String imageBase64) {
        return switchProvider().verifyLiveFaceAgainstGroup(imageBase64);
    }

    @Override
    public FaceVerifyResult verifyImageLiveness(String imageBase64) {
        return switchProvider().verifyImageLiveness(imageBase64);
    }

    private FaceRecognitionService switchProvider() {
        if ("TENCENT".equals(activeProvider())) {
            return new TencentAdapter(tencentFaceService);
        }
        return new BaiduAdapter(baiduFaceService);
    }

    private String activeProvider() {
        String provider = providerConfig.getProvider();
        return provider == null || provider.isBlank()
                ? "BAIDU"
                : provider.trim().toUpperCase();
    }

    private record BaiduAdapter(BaiduFaceService service) implements FaceRecognitionService {
        @Override
        public boolean isConfigured() {
            return service.isConfigured();
        }

        @Override
        public String getProviderName() {
            return "BAIDU";
        }

        @Override
        public String getFaceGroup() {
            return service.getFaceGroup();
        }

        @Override
        public String getLivenessMode() {
            return "IMAGE_LIVENESS";
        }

        @Override
        public boolean isDynamicLivenessReady() {
            return false;
        }

        @Override
        public boolean registerFace(String userId, String imageBase64) {
            return service.registerFace(userId, imageBase64, service.getFaceGroup());
        }

        @Override
        public FaceSearchResult verifyLiveFaceAgainstGroup(String imageBase64) {
            BaiduFaceService.FaceSearchResult result =
                    service.verifyLiveFaceAgainstGroup(imageBase64, service.getFaceGroup());
            return new FaceSearchResult(
                    result.userId(),
                    result.score(),
                    result.passed(),
                    result.livenessPassed(),
                    result.message()
            );
        }

        @Override
        public FaceVerifyResult verifyImageLiveness(String imageBase64) {
            BaiduFaceService.FaceVerifyResult result = service.verifyImageLiveness(imageBase64);
            return new FaceVerifyResult(
                    result.livenessPassed(),
                    result.livenessScore(),
                    result.errorCode(),
                    result.message()
            );
        }
    }

    private record TencentAdapter(TencentFaceService service) implements FaceRecognitionService {
        @Override
        public boolean isConfigured() {
            return service.isConfigured();
        }

        @Override
        public String getProviderName() {
            return "TENCENT";
        }

        @Override
        public String getFaceGroup() {
            return service.getFaceGroup();
        }

        @Override
        public String getLivenessMode() {
            return "APP_ACTION_CAPTURE_AND_CLOUD_MATCH";
        }

        @Override
        public boolean isDynamicLivenessReady() {
            return false;
        }

        @Override
        public boolean registerFace(String userId, String imageBase64) {
            return service.registerFace(userId, imageBase64);
        }

        @Override
        public FaceSearchResult verifyLiveFaceAgainstGroup(String imageBase64) {
            return service.verifyLiveFaceAgainstGroup(imageBase64);
        }

        @Override
        public FaceVerifyResult verifyImageLiveness(String imageBase64) {
            return service.verifyImageLiveness(imageBase64);
        }
    }
}
