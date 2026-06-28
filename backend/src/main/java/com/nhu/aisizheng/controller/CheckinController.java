package com.nhu.aisizheng.controller;

import com.nhu.aisizheng.common.Result;
import com.nhu.aisizheng.common.BusinessException;
import com.nhu.aisizheng.model.CheckinRecord;
import com.nhu.aisizheng.model.CheckinSite;
import com.nhu.aisizheng.model.ClassSession;
import com.nhu.aisizheng.repository.ClassSessionRepository;
import com.nhu.aisizheng.repository.CheckinSiteRepository;
import com.nhu.aisizheng.service.CheckinService;
import com.nhu.aisizheng.utils.JwtUtils;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.constraints.NotNull;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

/**
 * 打卡接口 — 支持定位+人脸双重验证
 */
@RestController
@RequestMapping("/checkin")
@RequiredArgsConstructor
public class CheckinController {

    private final CheckinService checkinService;
    private final JwtUtils jwtUtils;
    private final CheckinSiteRepository siteRepository;
    private final ClassSessionRepository classSessionRepository;

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
        CheckinRecord record = checkinService.classCheckin(
                userId, req.latitude, req.longitude,
                req.siteId, req.deviceInfo, getIp(request), req.faceImage);
        return Result.success(toMap(record));
    }

    /** 教师端生成课堂动态码，默认30秒过期 */
    @PostMapping("/class/qr")
    public Result<Map<String, Object>> generateClassQr(@RequestBody ClassQrRequest req) {
        ClassSession session = classSessionRepository.findById(req.sessionId)
                .orElseThrow(() -> new BusinessException("课堂场次不存在"));
        if (!"ACTIVE".equals(session.getStatus())) {
            throw new BusinessException("课堂场次未启用");
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
        LocalDateTime now = LocalDateTime.now();
        if (now.isBefore(session.getSignStartTime()) || now.isAfter(session.getSignEndTime())) {
            throw new BusinessException("当前不在该课堂签到时间窗口内");
        }
        Long userId = getUserId(request);
        CheckinRecord record = checkinService.classSessionCheckin(
                userId, req.latitude, req.longitude,
                siteId, sessionId, req.deviceInfo, getIp(request), req.faceImage);
        return Result.success(toMap(record));
    }

    /** 实习打卡 */
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
        String token = request.getHeader("Authorization").replace("Bearer ", "");
        return jwtUtils.getUserId(token);
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

    private String formatMessage(CheckinRecord r) {
        if ("SUCCESS".equals(r.getStatus())) return "打卡成功";
        return r.getFailReason() != null ? r.getFailReason() : "打卡失败";
    }

    // --- Request DTO ---
    public record CheckinRequest(
            @NotNull BigDecimal latitude,
            @NotNull BigDecimal longitude,
            @NotNull Long siteId,
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
}
