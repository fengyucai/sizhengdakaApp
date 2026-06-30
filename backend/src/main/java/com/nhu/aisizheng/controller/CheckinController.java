package com.nhu.aisizheng.controller;

import com.nhu.aisizheng.common.Result;
import com.nhu.aisizheng.common.BusinessException;
import com.nhu.aisizheng.model.CheckinRecord;
import com.nhu.aisizheng.model.CheckinSite;
import com.nhu.aisizheng.model.ClassSession;
import com.nhu.aisizheng.model.Notification;
import com.nhu.aisizheng.model.User;
import com.nhu.aisizheng.repository.ClassSessionRepository;
import com.nhu.aisizheng.repository.CheckinSiteRepository;
import com.nhu.aisizheng.repository.CheckinRecordRepository;
import com.nhu.aisizheng.repository.NotificationRepository;
import com.nhu.aisizheng.repository.InternLogRepository;
import com.nhu.aisizheng.repository.LeaveRequestRepository;
import com.nhu.aisizheng.repository.UserRepository;
import com.nhu.aisizheng.service.CheckinService;
import com.nhu.aisizheng.utils.JwtUtils;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.constraints.NotNull;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * 打卡接口 — 支持定位+人脸双重验证
 */
@RestController
@RequestMapping("/checkin")
@RequiredArgsConstructor
@Tag(name = "学生打卡", description = "查寝、课堂、实习打卡、记录、统计和申诉")
public class CheckinController {

    private final CheckinService checkinService;
    private final JwtUtils jwtUtils;
    private final CheckinSiteRepository siteRepository;
    private final ClassSessionRepository classSessionRepository;
    private final CheckinRecordRepository checkinRecordRepository;
    private final NotificationRepository notificationRepository;
    private final LeaveRequestRepository leaveRequestRepository;
    private final InternLogRepository internLogRepository;
    private final UserRepository userRepository;

    /** 查寝打卡 (定位+人脸) */
    @PostMapping("/dorm")
    public Result<Map<String, Object>> dormCheckin(
            @RequestBody CheckinRequest req,
            HttpServletRequest request) {
        Long userId = getUserId(request);
        CheckinRecord record = checkinService.dormCheckin(
                userId, req.latitude, req.longitude,
                req.siteId, req.deviceInfo, getIp(request), req.faceImage);
        return Result.success(toMap(record));
    }

    /** 上课打卡 */
    @PostMapping("/class")
    public Result<Map<String, Object>> classCheckin(
            @RequestBody CheckinRequest req,
            HttpServletRequest request) {
        Long userId = getUserId(request);
        CheckinRecord record = req.sessionId != null
                ? checkinService.classSessionCheckinByMode(
                        userId,
                        classSessionRepository.findById(req.sessionId)
                                .orElseThrow(() -> new BusinessException("课堂场次不存在")),
                        req.latitude, req.longitude, req.deviceInfo, getIp(request), req.faceImage)
                : checkinService.classCheckin(
                        userId, req.latitude, req.longitude,
                        req.siteId, req.deviceInfo, getIp(request), req.faceImage);
        return Result.success(toMap(record));
    }

    /** 教师端生成课堂动态码，默认30秒过期 */
    @PostMapping("/class/qr")
    public Result<Map<String, Object>> generateClassQr(@RequestBody ClassQrRequest req, HttpServletRequest request) {
        ClassSession session = classSessionRepository.findById(req.sessionId)
                .orElseThrow(() -> new BusinessException("课堂场次不存在"));
        assertCanManageClass(request, session.getClassId());
        if (!"ACTIVE".equals(session.getStatus())) {
            throw new BusinessException("课堂场次未启用");
        }
        if (!"QR".equals(session.getSignMode())) {
            throw new BusinessException("该课堂场次不是二维码签到");
        }
        LocalDateTime now = LocalDateTime.now();
        if (now.isBefore(session.getSignStartTime()) || now.isAfter(session.getSignEndTime())) {
            throw new BusinessException("当前不在该课堂签到时间窗口内");
        }
        CheckinSite site = siteRepository.findById(session.getSiteId())
                .orElseThrow(() -> new BusinessException("课堂打卡点不存在"));
        if (!"CLASSROOM".equals(site.getSiteType())) {
            throw new BusinessException("该打卡点不是课堂类型");
        }
        long expiresIn = req.expiresInSeconds != null ? req.expiresInSeconds : 30L;
        if (expiresIn < 10 || expiresIn > 120) {
            throw new BusinessException("动态码有效期需在10-120秒之间");
        }
        long windowSeconds = Math.max(1, java.time.Duration.between(now, session.getSignEndTime()).getSeconds());
        expiresIn = Math.min(expiresIn, windowSeconds);
        String token = jwtUtils.generateClassQrToken(site.getId(), session.getId(), expiresIn);
        return Result.success(Map.of(
                "token", token,
                "siteId", site.getId(),
                "sessionId", session.getId(),
                "siteName", site.getSiteName(),
                "courseName", session.getCourseName(),
                "teacherName", session.getTeacherName(),
                "expiresInSeconds", expiresIn,
                "expiresAt", Instant.now().plusSeconds(expiresIn).toString()
        ));
    }

    /** 学生扫码课堂签到 */
    @PostMapping("/class/scan")
    public Result<Map<String, Object>> classScanCheckin(
            @RequestBody ClassScanRequest req,
            HttpServletRequest request) {
        Long siteId;
        Long sessionId;
        try {
            siteId = jwtUtils.getClassQrSiteId(req.qrToken);
            sessionId = jwtUtils.getClassQrSessionId(req.qrToken);
        } catch (Exception e) {
            throw new BusinessException("动态码无效或已过期，请重新扫码");
        }
        ClassSession session = classSessionRepository.findById(sessionId)
                .orElseThrow(() -> new BusinessException("课堂场次不存在"));
        if (!"ACTIVE".equals(session.getStatus())) {
            throw new BusinessException("课堂场次已关闭");
        }
        if (!"QR".equals(session.getSignMode())) {
            throw new BusinessException("该课堂场次不是二维码签到");
        }
        LocalDateTime now = LocalDateTime.now();
        if (now.isBefore(session.getSignStartTime()) || now.isAfter(session.getSignEndTime())) {
            throw new BusinessException("当前不在该课堂签到时间窗口内");
        }
        Long userId = getUserId(request);
        CheckinRecord record = checkinService.classSessionCheckinByMode(
                userId, session, req.latitude, req.longitude, req.deviceInfo, getIp(request), req.faceImage);
        return Result.success(toMap(record));
    }

    /** 实习打卡 */
    @GetMapping("/class/sessions/active")
    public Result<List<Map<String, Object>>> activeClassSessions(HttpServletRequest request) {
        Long userId = getUserId(request);
        var user = userRepository.findById(userId)
                .orElseThrow(() -> new BusinessException("用户不存在"));
        LocalDateTime now = LocalDateTime.now();
        List<ClassSession> sessions = new java.util.ArrayList<>(
                classSessionRepository.findByStatusAndSignEndTimeGreaterThanEqualAndClassIdIsNullOrderBySignStartTimeAsc(
                        "ACTIVE", now));
        if (user.getClassId() != null) {
            sessions.addAll(classSessionRepository
                    .findByClassIdAndStatusAndSignEndTimeGreaterThanEqualOrderBySignStartTimeAsc(
                            user.getClassId(), "ACTIVE", now));
        }
        return Result.success(sessions.stream()
                .filter(session -> checkinRecordRepository
                        .findSuccessfulClassSessionCheckin(userId, session.getId())
                        .isEmpty())
                .sorted(java.util.Comparator.comparing(ClassSession::getSignStartTime))
                .map(session -> {
                    CheckinSite site = siteRepository.findById(session.getSiteId()).orElse(null);
                    Map<String, Object> row = new LinkedHashMap<>();
                    row.put("id", session.getId());
                    row.put("courseName", session.getCourseName());
                    row.put("teacherName", session.getTeacherName());
                    row.put("classId", session.getClassId());
                    row.put("siteId", session.getSiteId());
                    row.put("signMode", session.getSignMode() != null ? session.getSignMode() : "LOCATION");
                    row.put("siteName", site != null ? site.getSiteName() : "");
                    row.put("siteAddress", site != null && site.getDetailAddress() != null ? site.getDetailAddress() : "");
                    row.put("startTime", session.getStartTime().toString());
                    row.put("endTime", session.getEndTime().toString());
                    row.put("signStartTime", session.getSignStartTime().toString());
                    row.put("signEndTime", session.getSignEndTime().toString());
                    row.put("active", !now.isBefore(session.getSignStartTime()) && !now.isAfter(session.getSignEndTime()));
                    return row;
                })
                .toList());
    }

    @PostMapping("/intern")
    public Result<Map<String, Object>> internCheckin(
            @RequestBody CheckinRequest req,
            HttpServletRequest request) {
        Long userId = getUserId(request);
        CheckinRecord record = checkinService.internCheckin(
                userId, req.latitude, req.longitude,
                req.siteId, req.deviceInfo, getIp(request), req.logContent);
        return Result.success(toMap(record));
    }

    /** 查询今日打卡状态 */
    @GetMapping("/status/today")
    public Result<Map<String, Object>> todayStatus(HttpServletRequest request) {
        return Result.success(checkinService.getTodayStatus(getUserId(request)));
    }

    /** 查询个人打卡历史 */
    @GetMapping("/records")
    public Result<List<Map<String, Object>>> myRecords(
            @RequestParam(defaultValue = "30") int limit,
            HttpServletRequest request) {
        Long userId = getUserId(request);
        int size = Math.max(1, Math.min(limit, 100));
        return Result.success(checkinRecordRepository.findByUserIdOrderByCheckinTimeDesc(userId, PageRequest.of(0, size))
                .stream()
                .map(this::recordDetailMap)
                .toList());
    }

    /** 查询个人近30日考勤统计 */
    @GetMapping("/statistics/me")
    public Result<Map<String, Object>> myStatistics(HttpServletRequest request) {
        Long userId = getUserId(request);
        LocalDate today = LocalDate.now();
        LocalDateTime start = today.minusDays(29).atStartOfDay();
        LocalDateTime end = today.plusDays(1).atStartOfDay();

        List<CheckinRecord> records = checkinRecordRepository
                .findByUserIdAndCheckinTimeBetweenOrderByCheckinTimeDesc(userId, start, end);
        var leaves = leaveRequestRepository.findByUserIdOrderByCreatedAtDesc(userId);
        var logs = internLogRepository.findByUserIdOrderByWorkDateDesc(userId);

        long success = records.stream().filter(r -> "SUCCESS".equals(r.getStatus())).count();
        long failed = records.stream().filter(r -> !"SUCCESS".equals(r.getStatus())).count();
        long dorm = records.stream().filter(r -> "DORM".equals(r.getCheckinType()) && "SUCCESS".equals(r.getStatus())).count();
        long clazz = records.stream().filter(r -> "CLASS".equals(r.getCheckinType()) && "SUCCESS".equals(r.getStatus())).count();
        long intern = records.stream().filter(r -> "INTERNSHIP".equals(r.getCheckinType()) && "SUCCESS".equals(r.getStatus())).count();
        long pendingAppeals = records.stream().filter(r -> "PENDING".equals(r.getAppealStatus())).count();
        long approvedLeaves = leaves.stream().filter(l -> "APPROVED".equals(l.getStatus())).count();
        long pendingLeaves = leaves.stream().filter(l -> "PENDING".equals(l.getStatus())).count();

        Map<String, Object> data = new LinkedHashMap<>();
        data.put("rangeLabel", "近30日");
        data.put("successCount", success);
        data.put("failedCount", failed);
        data.put("dormCount", dorm);
        data.put("classCount", clazz);
        data.put("internCount", intern);
        data.put("pendingAppeals", pendingAppeals);
        data.put("approvedLeaves", approvedLeaves);
        data.put("pendingLeaves", pendingLeaves);
        data.put("internLogCount", logs.size());
        data.put("recentRecords", records.stream().limit(5).map(this::recordDetailMap).toList());
        return Result.success(data);
    }

    /** 对异常打卡记录发起申诉 */
    @PostMapping("/{id}/appeal")
    public Result<Map<String, Object>> appeal(
            @PathVariable Long id,
            @RequestBody AppealRequest req,
            HttpServletRequest request) {
        Long userId = getUserId(request);
        CheckinRecord record = checkinRecordRepository.findById(id)
                .orElseThrow(() -> new BusinessException("打卡记录不存在"));
        if (!userId.equals(record.getUserId())) {
            throw new BusinessException("无权申诉该打卡记录");
        }
        if ("SUCCESS".equals(record.getStatus())) {
            throw new BusinessException("成功打卡记录无需申诉");
        }
        if (record.getAppealStatus() != null && !"REJECTED".equals(record.getAppealStatus())) {
            throw new BusinessException("该记录已有待处理申诉");
        }
        String reason = req.reason == null ? "" : req.reason.trim();
        if (reason.isBlank()) {
            throw new BusinessException("请填写申诉原因");
        }
        if (record.getCheckinTime().isBefore(LocalDateTime.now().minusHours(24))) {
            throw new BusinessException("申诉需在异常发生后24小时内提交");
        }
        record.setAppealReason(reason);
        record.setAppealStatus("PENDING");
        record.setAppealReviewComment(null);
        record.setAppealedAt(LocalDateTime.now());
        record.setAppealReviewedAt(null);
        checkinRecordRepository.save(record);

        notificationRepository.save(Notification.builder()
                .receiverId(userId)
                .notifyType("INFO")
                .title("打卡申诉已提交")
                .content("你的打卡异常申诉已提交，等待辅导员审核。")
                .relatedType("APPEAL")
                .relatedId(record.getId())
                .read(false)
                .createdAt(LocalDateTime.now())
                .build());

        return Result.success(recordDetailMap(record));
    }

    /** 获取可用的打卡点列表 (可按距离排序) */
    @GetMapping("/sites")
    public Result<List<Map<String, Object>>> getSites(
            @RequestParam String type,
            @RequestParam(required = false) Double lat,
            @RequestParam(required = false) Double lng) {
        String siteType = switch (type.toUpperCase()) {
            case "DORM" -> "DORM";
            case "CLASS", "CLASSROOM" -> "CLASSROOM";
            case "INTERN", "INTERNSHIP" -> "INTERNSHIP";
            default -> type.toUpperCase();
        };
        List<CheckinSite> sites = siteRepository.findBySiteTypeAndStatus(siteType, "ACTIVE");

        // 如果有GPS坐标，按距离排序
        if (lat != null && lng != null) {
            sites.sort((a, b) -> Double.compare(
                    haversine(lat, lng, a.getLatitude().doubleValue(), a.getLongitude().doubleValue()),
                    haversine(lat, lng, b.getLatitude().doubleValue(), b.getLongitude().doubleValue())));
        }

        List<Map<String, Object>> result = sites.stream().map(s -> {
            double distance = lat != null && lng != null
                    ? haversine(lat, lng, s.getLatitude().doubleValue(), s.getLongitude().doubleValue())
                    : -1;
            return Map.<String, Object>of(
                    "id", s.getId(),
                    "name", s.getSiteName(),
                    "type", s.getSiteType(),
                    "latitude", s.getLatitude(),
                    "longitude", s.getLongitude(),
                    "radiusMeters", s.getRadiusMeters(),
                    "address", s.getDetailAddress() != null ? s.getDetailAddress() : "",
                    "distanceMeters", Math.round(distance)
            );
        }).toList();
        return Result.success(result);
    }

    /** 根据GPS自动选择最近打卡点 (无需用户手动选) */
    @GetMapping("/sites/best")
    public Result<Map<String, Object>> getBestSite(
            @RequestParam String type,
            @RequestParam double lat,
            @RequestParam double lng) {
        String siteType = switch (type.toUpperCase()) {
            case "DORM" -> "DORM";
            case "CLASS", "CLASSROOM" -> "CLASSROOM";
            case "INTERN", "INTERNSHIP" -> "INTERNSHIP";
            default -> type.toUpperCase();
        };
        List<CheckinSite> sites = siteRepository.findBySiteTypeAndStatus(siteType, "ACTIVE");
        if (sites.isEmpty()) return Result.fail("暂无可用的打卡点");

        CheckinSite best = sites.stream()
                .min((a, b) -> Double.compare(
                        haversine(lat, lng, a.getLatitude().doubleValue(), a.getLongitude().doubleValue()),
                        haversine(lat, lng, b.getLatitude().doubleValue(), b.getLongitude().doubleValue())))
                .orElse(sites.get(0));

        double dist = haversine(lat, lng, best.getLatitude().doubleValue(), best.getLongitude().doubleValue());
        boolean inRange = dist <= best.getRadiusMeters();

        return Result.success(Map.<String, Object>of(
                "id", best.getId(),
                "name", best.getSiteName(),
                "distanceMeters", Math.round(dist),
                "inRange", inRange,
                "radiusMeters", best.getRadiusMeters(),
                "latitude", best.getLatitude(),
                "longitude", best.getLongitude(),
                "type", best.getSiteType(),
                "address", best.getDetailAddress() != null ? best.getDetailAddress() : ""
        ));
    }

    private static double haversine(double lat1, double lng1, double lat2, double lng2) {
        final double R = 6_371_000;
        double dLat = Math.toRadians(lat2 - lat1);
        double dLng = Math.toRadians(lng2 - lng1);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                 + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                 * Math.sin(dLng / 2) * Math.sin(dLng / 2);
        return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    }

    // --- helpers ---

    private Long getUserId(HttpServletRequest request) {
        String header = request.getHeader("Authorization");
        if (header == null || !header.startsWith("Bearer ")) {
            throw new BusinessException(401, "未登录或Token已过期");
        }
        String token = header.substring(7);
        return jwtUtils.getUserId(token);
    }

    private void assertCanManageClass(HttpServletRequest request, Long classId) {
        User current = userRepository.findById(getUserId(request))
                .orElseThrow(() -> new BusinessException(401, "登录用户不存在"));
        if ("ADMIN".equals(current.getRole())) return;
        if (!"INSTRUCTOR".equals(current.getRole()) || current.getClassId() == null) {
            throw new BusinessException(403, "当前账号无课堂签到管理权限");
        }
        if (classId == null || !current.getClassId().equals(classId)) {
            throw new BusinessException(403, "无权操作该班级签到场次");
        }
    }

    private String getIp(HttpServletRequest request) {
        String ip = request.getHeader("X-Forwarded-For");
        if (ip == null || ip.isBlank()) ip = request.getRemoteAddr();
        return ip;
    }

    private Map<String, Object> toMap(CheckinRecord r) {
        return Map.of(
                "id", r.getId(),
                "status", r.getStatus(),
                "locationPassed", r.getLocationPassed() != null && r.getLocationPassed(),
                "facePassed", r.getFacePassed() != null && r.getFacePassed(),
                "faceScore", r.getFaceScore() != null ? r.getFaceScore().toString() : "N/A",
                "message", formatMessage(r)
        );
    }

    private Map<String, Object> recordDetailMap(CheckinRecord r) {
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("id", r.getId());
        data.put("type", r.getCheckinType());
        data.put("typeLabel", getTypeLabel(r.getCheckinType()));
        data.put("time", r.getCheckinTime() != null ? r.getCheckinTime().toString() : "");
        data.put("status", r.getStatus());
        data.put("locationPassed", r.getLocationPassed() != null && r.getLocationPassed());
        data.put("facePassed", r.getFacePassed() != null && r.getFacePassed());
        data.put("livenessPassed", r.getLivenessPassed() != null && r.getLivenessPassed());
        data.put("faceScore", r.getFaceScore() != null ? r.getFaceScore().toString() : "");
        data.put("failReason", r.getFailReason() != null ? r.getFailReason() : "");
        data.put("appealReason", r.getAppealReason() != null ? r.getAppealReason() : "");
        data.put("appealStatus", r.getAppealStatus() != null ? r.getAppealStatus() : "");
        data.put("appealReviewComment", r.getAppealReviewComment() != null ? r.getAppealReviewComment() : "");
        return data;
    }

    private String getTypeLabel(String type) {
        return switch (type) {
            case "DORM" -> "查寝";
            case "CLASS" -> "上课";
            case "INTERNSHIP" -> "实习";
            default -> type;
        };
    }

    private String formatMessage(CheckinRecord r) {
        if ("SUCCESS".equals(r.getStatus())) return "打卡成功";
        return r.getFailReason() != null ? r.getFailReason() : "打卡失败";
    }

    // --- Request DTO ---
    public record CheckinRequest(
            @NotNull BigDecimal latitude,
            @NotNull BigDecimal longitude,
            @NotNull Long siteId,
            Long sessionId,
            String deviceInfo,
            String faceImage,
            String logContent) {}

    public record ClassQrRequest(
            @NotNull Long sessionId,
            Long expiresInSeconds) {}

    public record ClassScanRequest(
            @NotNull String qrToken,
            @NotNull BigDecimal latitude,
            @NotNull BigDecimal longitude,
            String deviceInfo,
            String faceImage) {}

    public record AppealRequest(String reason) {}
}
