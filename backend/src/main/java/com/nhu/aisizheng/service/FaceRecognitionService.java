package com.nhu.aisizheng.service;

public interface FaceRecognitionService {
    boolean isConfigured();

    String getProviderName();

    String getFaceGroup();

    String getLivenessMode();

    boolean isDynamicLivenessReady();

    boolean registerFace(String userId, String imageBase64);

    FaceSearchResult verifyLiveFaceAgainstGroup(String imageBase64);

    FaceVerifyResult verifyImageLiveness(String imageBase64);

    record FaceSearchResult(
            String userId,
            Double score,
            Boolean passed,
            Boolean livenessPassed,
            String message
    ) {}

    record FaceVerifyResult(
            Boolean livenessPassed,
            Double livenessScore,
            Integer errorCode,
            String message
    ) {}
}
