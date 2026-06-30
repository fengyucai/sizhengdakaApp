package com.nhu.aisizheng.service;

import com.nhu.aisizheng.common.BusinessException;
import com.nhu.aisizheng.model.CheckinRecord;
import com.nhu.aisizheng.model.CheckinSite;
import com.nhu.aisizheng.model.ClassSession;
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
    private final FaceRecognitionService faceRecognitionService;

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

    @Transactional
    public CheckinRecord classSessionCheckinByMode(Long userId, ClassSession session,
                                                   BigDecimal lat, BigDecimal lng,
                                                   String deviceInfo, String ip, String faceImage) {
        checkinRecordRepository.findSuccessfulClassSessionCheckin(userId, session.getId())
                .ifPresent(c -> {
                    throw new BusinessException("该课堂场次已签到，无需重复签到");
                });

        LocalDateTime now = LocalDateTime.now();
        if (!"ACTIVE".equals(session.getStatus())) {
            throw new BusinessException("课堂场次未启用");
        }
        if (now.isBefore(session.getSignStartTime()) || now.isAfter(session.getSignEndTime())) {
            throw new BusinessException("当前不在该课堂签到时间窗口内");
        }

        CheckinSite site = checkinSiteRepository.findById(session.getSiteId())
                .orElseThrow(() -> new BusinessException("课堂打卡点不存在"));
        if (!"CLASSROOM".equals(site.getSiteType()) || !"ACTIVE".equals(site.getStatus())) {
            throw new BusinessException("课堂打卡点未启用");
        }

        String mode = session.getSignMode() == null ? "LOCATION" : session.getSignMode();
        boolean needLocation = "LOCATION".equals(mode);
        boolean needFace = "PHOTO".equals(mode);
        boolean locationOk = true;
        boolean faceOk = true;
        boolean livenessOk = true;
        BigDecimal faceScore = null;
        String failReason = null;
        BigDecimal recordLat = lat != null ? lat : site.getLatitude();
        BigDecimal recordLng = lng != null ? lng : site.getLongitude();

        if (needLocation) {
            if (lat == null || lng == null) {
                locationOk = false;
                failReason = "位置签到必须提交实时定位";
            } else {
                double distance = GeoUtils.haversineDistance(lat, lng, site.getLatitude(), site.getLongitude());
                locationOk = distance <= site.getRadiusMeters();
                if (!locationOk) {
                    failReason = "不在课堂签到范围内(距离" + Math.round(distance)
                            + "米, 允许" + site.getRadiusMeters() + "米)";
                }
            }
        }

        if (needFace) {
            userRepository.findById(userId)
                    .filter(user -> Boolean.TRUE.equals(user.getFaceRegistered()))
                    .orElseThrow(() -> new BusinessException("请先完成人脸注册"));
            if (faceImage == null || faceImage.isBlank()) {
                faceOk = false;
                livenessOk = false;
                failReason = "拍照签到必须提交实时人脸照片";
            } else {
                if (!faceRecognitionService.isConfigured()) {
                    throw new BusinessException("未配置人脸识别服务密钥，无法进行真实人脸签到");
                }
                FaceRecognitionService.FaceSearchResult faceResult =
                        faceRecognitionService.verifyLiveFaceAgainstGroup(faceImage);
                faceOk = faceResult.passed();
                faceScore = BigDecimal.valueOf(faceResult.score());
                livenessOk = faceResult.livenessPassed();
                if (faceOk && faceResult.userId() != null && !String.valueOf(userId).equals(faceResult.userId())) {
                    faceOk = false;
                    failReason = "人脸身份与当前登录用户不一致";
                }
                if (!faceOk || !livenessOk) {
                    failReason = failReason != null ? failReason : faceResult.message();
                    if (!livenessOk) failReason = "在线活体检测未通过，请真人现场采集";
                }
            }
        }

        boolean success = locationOk && faceOk && livenessOk;
        CheckinRecord record = CheckinRecord.builder()
                .userId(userId)
                .siteId(site.getId())
                .sessionId(session.getId())
                .checkinType("CLASS")
                .checkinTime(now)
                .latitude(recordLat)
                .longitude(recordLng)
                .locationPassed(locationOk)
                .facePassed(faceOk)
                .faceScore(faceScore)
                .livenessPassed(livenessOk)
                .status(success ? "SUCCESS" : "FAILED")
                .failReason(failReason)
                .deviceInfo((deviceInfo == null ? "" : deviceInfo) + " mode=" + mode)
                .ipAddress(ip)
                .createdAt(now)
                .build();
        checkinRecordRepository.save(record);
        return record;
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

        if ("DORM".equals(type) || "CLASS".equals(type)) {
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

        if (("DORM".equals(type) || "CLASS".equals(type))
                && (faceImage == null || faceImage.isBlank())) {
            faceOk = false;
            livenessOk = false;
            faceFailReason = getTypeLabel(type) + "打卡必须提交实时人脸照片";
        } else if (faceImage != null && !faceImage.isBlank()
                && ("DORM".equals(type) || "CLASS".equals(type))) {

            if (!faceRecognitionService.isConfigured()) {
                throw new BusinessException("未配置人脸识别服务密钥，无法进行真实人脸打卡");
            }
            FaceRecognitionService.FaceSearchResult faceResult =
                    faceRecognitionService.verifyLiveFaceAgainstGroup(faceImage);

            faceOk = faceResult.passed();
            faceScore = BigDecimal.valueOf(faceResult.score());
            livenessOk = faceResult.livenessPassed();

            if (faceOk && faceResult.userId() != null
                    && !String.valueOf(userId).equals(faceResult.userId())) {
                faceOk = false;
                faceFailReason = "人脸身份与当前登录用户不一致";
            }

            if (!faceOk || !livenessOk) {
                if (faceFailReason == null) faceFailReason = faceResult.message();
                if (!livenessOk) faceFailReason = "在线活体检测未通过，请真人现场采集";
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
                        .countTodaySuccess(userId, "DORM", start, end) > 0 || hasApprovedLeave(userId, start, end),
                "classCheckin", checkinRecordRepository
                        .countTodaySuccess(userId, "CLASS", start, end) > 0 || hasApprovedLeave(userId, start, end),
                "intern", checkinRecordRepository
                        .countTodaySuccess(userId, "INTERNSHIP", start, end) > 0 || hasApprovedLeave(userId, start, end),
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
        if (trimmed.isBlank()) {
            throw new BusinessException("请填写实习日志");
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
