package com.nhu.aisizheng.service;

import com.nhu.aisizheng.common.BusinessException;
import com.nhu.aisizheng.model.CheckinRecord;
import com.nhu.aisizheng.model.CheckinSite;
import com.nhu.aisizheng.model.InternLog;
import com.nhu.aisizheng.repository.CheckinRecordRepository;
import com.nhu.aisizheng.repository.CheckinSiteRepository;
import com.nhu.aisizheng.repository.InternLogRepository;
import com.nhu.aisizheng.repository.LeaveRequestRepository;
import com.nhu.aisizheng.repository.UserRepository;
import com.nhu.aisizheng.utils.GeoUtils;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Map;

/**
 * 打卡核心服务 — 定位+人脸双重验证
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class CheckinService {

    private final CheckinRecordRepository checkinRecordRepository;
    private final CheckinSiteRepository checkinSiteRepository;
    private final InternLogRepository internLogRepository;
    private final LeaveRequestRepository leaveRequestRepository;
    private final UserRepository userRepository;
    private final BaiduFaceService baiduFaceService;
    private final MockFaceService mockFaceService;

    /** 查寝打卡 */
    @Transactional
    public CheckinRecord dormCheckin(Long userId, BigDecimal lat, BigDecimal lng,
                                      Long siteId, String deviceInfo, String ip, String faceImage) {
        return doCheckin(userId, lat, lng, siteId, null, "DORM", deviceInfo, ip, faceImage);
    }

    /** 上课打卡 */
    @Transactional
    public CheckinRecord classCheckin(Long userId, BigDecimal lat, BigDecimal lng,
                                       Long siteId, String deviceInfo, String ip, String faceImage) {
        return doCheckin(userId, lat, lng, siteId, null, "CLASS", deviceInfo, ip, faceImage);
    }

    /** 上课场次签到 */
    @Transactional
    public CheckinRecord classSessionCheckin(Long userId, BigDecimal lat, BigDecimal lng,
                                             Long siteId, Long sessionId, String deviceInfo, String ip, String faceImage) {
        return doCheckin(userId, lat, lng, siteId, sessionId, "CLASS", deviceInfo, ip, faceImage);
    }

    /** 实习打卡 (无人脸) */
    @Transactional
    public CheckinRecord internCheckin(Long userId, BigDecimal lat, BigDecimal lng,
                                        Long siteId, String deviceInfo, String ip, String logContent) {
        CheckinRecord record = doCheckin(userId, lat, lng, siteId, null, "INTERNSHIP", deviceInfo, ip, null);
        if ("SUCCESS".equals(record.getStatus())) {
            saveInternLog(userId, record.getSiteId(), logContent);
        }
        return record;
    }

    private CheckinRecord doCheckin(Long userId, BigDecimal lat, BigDecimal lng,
                                     Long siteId, Long sessionId, String type, String deviceInfo,
                                     String ip, String faceImage) {
        // 1. 防重复打卡
        LocalDate today = LocalDate.now();
        if ("CLASS".equals(type) && sessionId != null) {
            checkinRecordRepository.findSuccessfulClassSessionCheckin(userId, sessionId)
                    .ifPresent(c -> {
                        throw new BusinessException("该课堂场次已签到，无需重复签到");
                    });
        } else if ("CLASS".equals(type)) {
            checkinRecordRepository.findTodayCheckinAtSite(userId, type, siteId,
                    today.atStartOfDay(), today.plusDays(1).atStartOfDay()
            ).ifPresent(c -> {
                throw new BusinessException("今日已在该课堂签到，无需重复签到");
            });
        } else {
            checkinRecordRepository.findTodayCheckin(userId, type,
                    today.atStartOfDay(), today.plusDays(1).atStartOfDay()
            ).ifPresent(c -> {
                throw new BusinessException("今日已" + getTypeLabel(type) + "打卡，无需重复打卡");
            });
        }

        // 2. 获取打卡点配置
        CheckinSite site = checkinSiteRepository.findById(siteId)
                .orElseThrow(() -> new BusinessException("打卡点不存在"));

        if ("DORM".equals(type)) {
            userRepository.findById(userId)
                    .filter(user -> Boolean.TRUE.equals(user.getFaceRegistered()))
                    .orElseThrow(() -> new BusinessException("请先完成人脸注册"));
        }

        // 3. 位置验证 (GPS电子围栏)
        double distance = GeoUtils.haversineDistance(lat, lng,
                site.getLatitude(), site.getLongitude());
        boolean locationOk = distance <= site.getRadiusMeters();

        // 4. 人脸验证 (查寝强制，上课按提交照片严格校验，实习不强制)
        boolean faceOk = true;
        BigDecimal faceScore = null;
        boolean livenessOk = true;
        String faceFailReason = null;

        if ("DORM".equals(type) && (faceImage == null || faceImage.isBlank())) {
            faceOk = false;
            livenessOk = false;
            faceFailReason = "查寝打卡必须提交实时人脸照片";
        } else if (faceImage != null && !faceImage.isBlank()
                && ("DORM".equals(type) || "CLASS".equals(type))) {

            BaiduFaceService.FaceSearchResult faceResult;
            if (baiduFaceService.isConfigured()) {
                faceResult = baiduFaceService.searchFace(faceImage, "dorm_checkin");
            } else {
                faceResult = mockFaceService.searchFace(faceImage, "dorm_checkin");
            }

            faceOk = faceResult.passed();
            faceScore = BigDecimal.valueOf(faceResult.score());
            livenessOk = faceResult.livenessPassed();

            if (faceOk && faceResult.userId() != null
                    && !"MOCK_USER".equals(faceResult.userId())
                    && !String.valueOf(userId).equals(faceResult.userId())) {
                faceOk = false;
                faceFailReason = "人脸身份与当前登录用户不一致";
            }

            if (!faceOk || !livenessOk) {
                if (faceFailReason == null) faceFailReason = faceResult.message();
                if (!livenessOk) faceFailReason = "活体检测未通过 (请真人出镜)";
            }

            log.info("人脸验证: userId={}, score={}, faceOk={}, livenessOk={}",
                    userId, faceScore, faceOk, livenessOk);
        }

        // 5. 综合判定
        boolean overallSuccess = locationOk && faceOk && livenessOk;
        String failReason = null;
        if (!locationOk) {
            failReason = "不在打卡范围内 (距离" + Math.round(distance)
                    + "米, 允许" + site.getRadiusMeters() + "米)";
        } else if (!faceOk || !livenessOk) {
            failReason = faceFailReason;
        }

        // 6. 保存打卡记录
        CheckinRecord record = CheckinRecord.builder()
                .userId(userId)
                .siteId(siteId)
                .sessionId(sessionId)
                .checkinType(type)
                .checkinTime(LocalDateTime.now())
                .latitude(lat)
                .longitude(lng)
                .locationPassed(locationOk)
                .facePassed(faceOk)
                .faceScore(faceScore)
                .livenessPassed(livenessOk)
                .status(overallSuccess ? "SUCCESS" : "FAILED")
                .failReason(failReason)
                .deviceInfo(deviceInfo)
                .ipAddress(ip)
                .build();

        checkinRecordRepository.save(record);
        log.info("打卡完成: userId={} type={} location={} face={} status={}",
                userId, getTypeLabel(type), locationOk, faceOk, record.getStatus());
        return record;
    }

    /** 查询今日打卡状态 */
    public Map<String, Object> getTodayStatus(Long userId) {
        LocalDate today = LocalDate.now();
        LocalDateTime start = today.atStartOfDay();
        LocalDateTime end = today.plusDays(1).atStartOfDay();

        return Map.of(
                "dorm", checkinRecordRepository
                        .findTodayCheckin(userId, "DORM", start, end).isPresent() || hasApprovedLeave(userId, start, end),
                "classCheckin", checkinRecordRepository
                        .findTodayCheckin(userId, "CLASS", start, end).isPresent() || hasApprovedLeave(userId, start, end),
                "intern", checkinRecordRepository
                        .findTodayCheckin(userId, "INTERNSHIP", start, end).isPresent() || hasApprovedLeave(userId, start, end),
                "leaveExempt", hasApprovedLeave(userId, start, end)
        );
    }

    private String getTypeLabel(String type) {
        return switch (type) {
            case "DORM" -> "查寝";
            case "CLASS" -> "上课";
            case "INTERNSHIP" -> "实习";
            default -> type;
        };
    }

    private void saveInternLog(Long userId, Long siteId, String content) {
        String trimmed = content == null ? "" : content.trim();
        if (trimmed.length() < 50 || trimmed.length() > 300) {
            throw new BusinessException("实习日志需填写50-300字");
        }
        CheckinSite site = checkinSiteRepository.findById(siteId)
                .orElseThrow(() -> new BusinessException("实习单位不存在"));
        LocalDate today = LocalDate.now();
        InternLog log = internLogRepository.findByUserIdAndWorkDate(userId, today)
                .orElseGet(() -> InternLog.builder()
                        .userId(userId)
                        .workDate(today)
                        .companyName(site.getSiteName())
                        .createdAt(LocalDateTime.now())
                        .build());
        log.setCompanyName(site.getSiteName());
        log.setContent(trimmed);
        internLogRepository.save(log);
    }

    private boolean hasApprovedLeave(Long userId, LocalDateTime start, LocalDateTime end) {
        return !leaveRequestRepository
                .findByUserIdAndStatusAndStartTimeLessThanEqualAndEndTimeGreaterThanEqual(
                        userId, "APPROVED", end, start)
                .isEmpty();
    }
}
