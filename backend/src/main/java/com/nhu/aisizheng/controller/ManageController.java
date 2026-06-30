package com.nhu.aisizheng.controller;

import com.nhu.aisizheng.common.BusinessException;
import com.nhu.aisizheng.common.Result;
import com.nhu.aisizheng.model.AuditLog;
import com.nhu.aisizheng.model.CheckinRecord;
import com.nhu.aisizheng.model.CheckinSite;
import com.nhu.aisizheng.model.ClassSession;
import com.nhu.aisizheng.model.InternLog;
import com.nhu.aisizheng.model.LeaveRequest;
import com.nhu.aisizheng.model.Notification;
import com.nhu.aisizheng.model.User;
import com.nhu.aisizheng.repository.AuditLogRepository;
import com.nhu.aisizheng.repository.CheckinRecordRepository;
import com.nhu.aisizheng.repository.CheckinSiteRepository;
import com.nhu.aisizheng.repository.ClassSessionRepository;
import com.nhu.aisizheng.repository.InternLogRepository;
import com.nhu.aisizheng.repository.LeaveRequestRepository;
import com.nhu.aisizheng.repository.NotificationRepository;
import com.nhu.aisizheng.repository.UserRepository;
import com.nhu.aisizheng.service.AuditLogService;
import com.nhu.aisizheng.service.NotificationStreamService;
import com.nhu.aisizheng.utils.JwtUtils;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.nio.charset.StandardCharsets;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * 管理端基础接口。
 */
@RestController
@RequestMapping("/manage")
@RequiredArgsConstructor
@Tag(name = "教师管理端", description = "教师工作台、学生管理、审批、签到场次、预警、审计和报表")
public class ManageController {

    private final UserRepository userRepository;
    private final CheckinSiteRepository checkinSiteRepository;
    private final CheckinRecordRepository checkinRecordRepository;
    private final ClassSessionRepository classSessionRepository;
    private final InternLogRepository internLogRepository;
    private final LeaveRequestRepository leaveRequestRepository;
    private final NotificationRepository notificationRepository;
    private final AuditLogRepository auditLogRepository;
    private final AuditLogService auditLogService;
    private final NotificationStreamService notificationStreamService;
    private final JwtUtils jwtUtils;

    @GetMapping("/dashboard")
    public Result<Map<String, Object>> dashboard(HttpServletRequest request) {
        LocalDateTime start = LocalDate.now().atStartOfDay();
        LocalDateTime end = start.plusDays(1);
        List<User> managedStudents = students(request);
        Set<Long> managedIds = managedStudents.stream().map(User::getId).collect(Collectors.toSet());
        long total = managedStudents.size();
        Map<String, Long> counts = checkinRecordRepository
                .findByCheckinTimeBetweenOrderByCheckinTimeDesc(start, end)
                .stream()
                .filter(r -> managedIds.contains(r.getUserId()))
                .filter(r -> "SUCCESS".equals(r.getStatus()))
                .collect(Collectors.groupingBy(CheckinRecord::getCheckinType, Collectors.counting()));
        long alerts = scopedWarnings(request).stream()
                .filter(n -> !Boolean.TRUE.equals(n.getRead()))
                .count();
        return Result.success(Map.of(
                "studentTotal", total,
                "dormChecked", counts.getOrDefault("DORM", 0L),
                "classChecked", counts.getOrDefault("CLASS", 0L),
                "internChecked", counts.getOrDefault("INTERNSHIP", 0L),
                "pendingAlerts", alerts,
                "dormRate", rate(counts.getOrDefault("DORM", 0L), total),
                "classRate", rate(counts.getOrDefault("CLASS", 0L), total),
                "internRate", rate(counts.getOrDefault("INTERNSHIP", 0L), total)
        ));
    }

    @GetMapping("/students")
    public Result<List<Map<String, Object>>> studentsList(HttpServletRequest request) {
        return Result.success(students(request).stream()
                .sorted(Comparator.comparing(User::getStudentId))
                .map(u -> Map.<String, Object>of(
                        "id", u.getId(),
                        "name", u.getRealName(),
                        "studentId", u.getStudentId(),
                        "classId", u.getClassId() != null ? u.getClassId() : 0,
                        "phone", u.getPhone() != null ? u.getPhone() : "",
                        "faceRegistered", Boolean.TRUE.equals(u.getFaceRegistered()),
                        "status", u.getStatus() != null ? u.getStatus() : ""
                ))
                .toList());
    }

    @GetMapping("/dorm/today-locations")
    public Result<List<Map<String, Object>>> dormTodayLocations(HttpServletRequest request) {
        LocalDateTime start = LocalDate.now().atStartOfDay();
        LocalDateTime end = start.plusDays(1);
        Map<Long, User> users = students(request).stream()
                .collect(Collectors.toMap(User::getId, Function.identity()));
        Map<Long, CheckinSite> sites = checkinSiteRepository.findAll().stream()
                .collect(Collectors.toMap(CheckinSite::getId, Function.identity()));
        List<Map<String, Object>> rows = checkinRecordRepository
                .findByCheckinTypeAndCheckinTimeBetweenOrderByCheckinTimeDesc("DORM", start, end)
                .stream()
                .filter(r -> users.containsKey(r.getUserId()))
                .map(r -> {
                    User u = users.get(r.getUserId());
                    CheckinSite site = sites.get(r.getSiteId());
                    double distance = site != null && r.getLatitude() != null && r.getLongitude() != null
                            ? haversine(r.getLatitude().doubleValue(), r.getLongitude().doubleValue(),
                                    site.getLatitude().doubleValue(), site.getLongitude().doubleValue())
                            : -1;
                    Map<String, Object> row = new java.util.LinkedHashMap<>();
                    row.put("id", r.getId());
                    row.put("name", u != null ? u.getRealName() : "");
                    row.put("studentId", u != null ? u.getStudentId() : "");
                    row.put("time", fmtDate(r.getCheckinTime()));
                    row.put("status", r.getStatus());
                    row.put("latitude", r.getLatitude() != null ? r.getLatitude() : BigDecimal.ZERO);
                    row.put("longitude", r.getLongitude() != null ? r.getLongitude() : BigDecimal.ZERO);
                    row.put("siteName", site != null ? site.getSiteName() : "");
                    row.put("siteLatitude", site != null ? site.getLatitude() : BigDecimal.ZERO);
                    row.put("siteLongitude", site != null ? site.getLongitude() : BigDecimal.ZERO);
                    row.put("distanceMeters", Math.round(distance));
                    row.put("radiusMeters", site != null ? site.getRadiusMeters() : 0);
                    row.put("locationPassed", Boolean.TRUE.equals(r.getLocationPassed()));
                    row.put("facePassed", Boolean.TRUE.equals(r.getFacePassed()));
                    row.put("livenessPassed", Boolean.TRUE.equals(r.getLivenessPassed()));
                    row.put("deviceInfo", r.getDeviceInfo() != null ? r.getDeviceInfo() : "");
                    row.put("ipAddress", r.getIpAddress() != null ? r.getIpAddress() : "");
                    row.put("failReason", r.getFailReason() != null ? r.getFailReason() : "");
                    return row;
                })
                .toList();
        return Result.success(rows);
    }

    @GetMapping("/class/mobile")
    public Result<Map<String, Object>> mobileClassWorkbench(HttpServletRequest request) {
        List<Map<String, Object>> sessions = classSessions(null, request).getData();
        List<Map<String, Object>> sites = manageSites("CLASSROOM", true).getData();
        return Result.success(Map.of(
                "sessions", sessions,
                "sites", sites,
                "students", studentsList(request).getData()
        ));
    }

    @PostMapping("/class/manual-checkin")
    public Result<Map<String, Object>> manualClassCheckin(@RequestBody ManualCheckinRequest req, HttpServletRequest request) {
        User student = userRepository.findById(req.userId)
                .filter(u -> "STUDENT".equals(u.getRole()) && "ACTIVE".equals(u.getStatus()))
                .orElseThrow(() -> new BusinessException("学生不存在或不可用"));
        assertCanManageStudent(request, student);
        CheckinSite site = checkinSiteRepository.findById(req.siteId)
                .orElseThrow(() -> new BusinessException("课堂打卡点不存在"));
        if (!"CLASSROOM".equals(site.getSiteType()) || !"ACTIVE".equals(site.getStatus())) {
            throw new BusinessException("请选择启用中的课堂打卡点");
        }
        LocalDateTime now = LocalDateTime.now();
        checkinRecordRepository.findTodayCheckinAtSite(student.getId(), "CLASS", site.getId(),
                now.toLocalDate().atStartOfDay(), now.toLocalDate().plusDays(1).atStartOfDay())
                .ifPresent(record -> {
                    throw new BusinessException("该学生今日已在该课堂点签到");
                });
        CheckinRecord record = CheckinRecord.builder()
                .userId(student.getId())
                .siteId(site.getId())
                .sessionId(req.sessionId)
                .checkinType("CLASS")
                .checkinTime(now)
                .latitude(site.getLatitude())
                .longitude(site.getLongitude())
                .locationPassed(true)
                .facePassed(true)
                .livenessPassed(true)
                .status("SUCCESS")
                .deviceInfo("TEACHER_MANUAL reviewer=" + currentUserId(request))
                .ipAddress("")
                .createdAt(now)
                .build();
        checkinRecordRepository.save(record);
        audit(request, "CLASS_MANUAL_CHECKIN", "CHECKIN_RECORD", record.getId(), Map.of(
                "studentId", student.getId(),
                "studentName", student.getRealName(),
                "siteId", site.getId(),
                "sessionId", req.sessionId != null ? req.sessionId : 0
        ));
        return Result.success(Map.of("id", record.getId(), "status", record.getStatus()));
    }

    @PostMapping("/class/mobile-session")
    public Result<Map<String, Object>> createMobileClassSession(@RequestBody MobileClassSessionRequest req, HttpServletRequest request) {
        String mode = req.mode == null ? "LOCATION" : req.mode.toUpperCase();
        if (!List.of("MANUAL", "QR", "LOCATION", "PHOTO").contains(mode)) {
            throw new BusinessException("签到方式不正确");
        }
        Long scopedClassId = scopedClassIdForCreate(request, req.classId);
        Long siteId = req.siteId;
        if (siteId == null) {
            siteId = checkinSiteRepository.findBySiteTypeAndStatus("CLASSROOM", "ACTIVE")
                    .stream()
                    .findFirst()
                    .orElseThrow(() -> new BusinessException("暂无启用课堂打卡点"))
                    .getId();
        }
        LocalDateTime now = LocalDateTime.now();
        int minutes = req.durationMinutes != null ? Math.max(5, Math.min(req.durationMinutes, 180)) : 45;
        ClassSessionRequest sessionReq = new ClassSessionRequest(
                req.courseName != null && !req.courseName.isBlank() ? req.courseName : "移动端课堂签到-" + mode,
                req.teacherName != null && !req.teacherName.isBlank() ? req.teacherName : "辅导员",
                scopedClassId,
                siteId,
                now,
                now.plusMinutes(minutes),
                now,
                now.plusMinutes(minutes),
                mode);
        Result<Map<String, Object>> created = createClassSession(sessionReq, request);
        Long sessionId = ((Number) created.getData().get("id")).longValue();
        Map<String, Object> data = new java.util.LinkedHashMap<>(created.getData());
        data.put("mode", mode);
        data.put("message", switch (mode) {
            case "MANUAL" -> "普通签到请求已发起，学生可在消息或上课打卡中点击签到";
            case "QR" -> "二维码签到场次已创建，可生成动态二维码给学生扫码";
            case "PHOTO" -> "拍照签到场次已创建，学生需提交实时人脸图像";
            default -> "位置签到场次已创建，学生需在电子围栏范围内签到";
        });
        if ("QR".equals(mode)) {
            data.put("qr", classQrData(sessionId, 60L));
        }
        return Result.success(data);
    }

    @GetMapping("/class/{classId}/dorm-today")
    public Result<List<Map<String, Object>>> dormToday(@PathVariable Long classId, HttpServletRequest request) {
        assertCanManageClass(request, classId);
        return Result.success(classCheckinRows(classId, "DORM", request));
    }

    @GetMapping("/class/{classId}/attendance")
    public Result<Map<String, Object>> attendance(@PathVariable Long classId, HttpServletRequest request) {
        assertCanManageClass(request, classId);
        List<Map<String, Object>> records = classCheckinRows(classId, "CLASS", request);
        long present = records.stream().filter(r -> Boolean.TRUE.equals(r.get("checked"))).count();
        return Result.success(Map.of(
                "total", records.size(),
                "present", present,
                "absent", Math.max(0, records.size() - present),
                "rate", rate(present, records.size()),
                "records", records
        ));
    }

    @GetMapping("/class/sessions")
    public Result<List<Map<String, Object>>> classSessions(@RequestParam(required = false) Long classId, HttpServletRequest request) {
        LocalDateTime start = LocalDate.now().atStartOfDay();
        LocalDateTime end = start.plusDays(1);
        Long scopedClassId = scopedClassIdForRead(request, classId);
        List<ClassSession> sessions = scopedClassId != null
                ? classSessionRepository.findByClassIdAndStatusAndStartTimeBetweenOrderByStartTimeAsc(scopedClassId, "ACTIVE", start, end)
                : classSessionRepository.findByStatusAndSignEndTimeGreaterThanEqualOrderByStartTimeAsc("ACTIVE", LocalDateTime.now());
        return Result.success(sessions.stream().map(s -> {
            Map<String, Object> row = new java.util.LinkedHashMap<>();
            row.put("id", s.getId());
            row.put("courseName", s.getCourseName());
            row.put("teacherName", s.getTeacherName());
            row.put("classId", s.getClassId() != null ? s.getClassId() : 0);
            row.put("siteId", s.getSiteId());
            row.put("signMode", s.getSignMode() != null ? s.getSignMode() : "LOCATION");
            row.put("startTime", fmtDate(s.getStartTime()));
            row.put("endTime", fmtDate(s.getEndTime()));
            row.put("signStartTime", fmtDate(s.getSignStartTime()));
            row.put("signEndTime", fmtDate(s.getSignEndTime()));
            row.put("active", !LocalDateTime.now().isBefore(s.getSignStartTime())
                    && !LocalDateTime.now().isAfter(s.getSignEndTime()));
            return row;
        }).toList());
    }

    @PostMapping("/class/session")
    public Result<Map<String, Object>> createClassSession(@RequestBody ClassSessionRequest req, HttpServletRequest request) {
        validateClassSession(req);
        Long scopedClassId = scopedClassIdForCreate(request, req.classId);
        CheckinSite site = checkinSiteRepository.findById(req.siteId)
                .orElseThrow(() -> new BusinessException("课堂打卡点不存在"));
        if (!"CLASSROOM".equals(site.getSiteType()) || !"ACTIVE".equals(site.getStatus())) {
            throw new BusinessException("请选择启用中的课堂打卡点");
        }
        ClassSession session = ClassSession.builder()
                .courseName(req.courseName.trim())
                .teacherName(req.teacherName.trim())
                .classId(scopedClassId)
                .siteId(req.siteId)
                .startTime(req.startTime)
                .endTime(req.endTime)
                .signStartTime(req.signStartTime)
                .signEndTime(req.signEndTime)
                .signMode(req.signMode != null && !req.signMode.isBlank() ? req.signMode.toUpperCase() : "LOCATION")
                .status("ACTIVE")
                .createdAt(LocalDateTime.now())
                .build();
        classSessionRepository.save(session);
        notifyClassSessionStudents(session);
        audit(request, "CLASS_SESSION_CREATE", "CLASS_SESSION", session.getId(), Map.of(
                "courseName", session.getCourseName(),
                "classId", session.getClassId() != null ? session.getClassId() : 0,
                "siteId", session.getSiteId(),
                "signMode", session.getSignMode()
        ));
        return Result.success(Map.of("id", session.getId()));
    }

    @PostMapping("/class/session/{id}/close")
    public Result<Void> closeClassSession(@PathVariable Long id, HttpServletRequest request) {
        ClassSession session = classSessionRepository.findById(id)
                .orElseThrow(() -> new BusinessException("课堂场次不存在"));
        assertCanManageClass(request, session.getClassId());
        session.setStatus("CLOSED");
        classSessionRepository.save(session);
        audit(request, "CLASS_SESSION_CLOSE", "CLASS_SESSION", session.getId(), Map.of(
                "courseName", session.getCourseName(),
                "classId", session.getClassId() != null ? session.getClassId() : 0
        ));
        return Result.success();
    }

    @GetMapping("/sites")
    public Result<List<Map<String, Object>>> manageSites(
            @RequestParam(required = false) String type,
            @RequestParam(defaultValue = "false") boolean activeOnly) {
        String normalizedType = type == null || type.isBlank() ? null : normalizeSiteType(type);
        List<CheckinSite> sites = checkinSiteRepository.findAll().stream()
                .filter(s -> normalizedType == null || normalizedType.equals(s.getSiteType()))
                .filter(s -> !activeOnly || "ACTIVE".equals(s.getStatus()))
                .toList();
        return Result.success(sites.stream().map(s -> Map.<String, Object>of(
                "id", s.getId(),
                "name", s.getSiteName(),
                "type", s.getSiteType(),
                "latitude", s.getLatitude(),
                "longitude", s.getLongitude(),
                "radiusMeters", s.getRadiusMeters(),
                "address", s.getDetailAddress() != null ? s.getDetailAddress() : "",
                "status", s.getStatus()
        )).toList());
    }

    @PostMapping("/sites")
    public Result<Map<String, Object>> createSite(@RequestBody SiteRequest req, HttpServletRequest request) {
        validateSite(req);
        CheckinSite site = CheckinSite.builder()
                .siteName(req.name.trim())
                .siteType(normalizeSiteType(req.type))
                .latitude(req.latitude)
                .longitude(req.longitude)
                .radiusMeters(req.radiusMeters != null ? req.radiusMeters : 300)
                .detailAddress(req.address)
                .status("ACTIVE")
                .createdAt(LocalDateTime.now())
                .build();
        checkinSiteRepository.save(site);
        audit(request, "SITE_CREATE", "CHECKIN_SITE", site.getId(), Map.of(
                "name", site.getSiteName(),
                "type", site.getSiteType(),
                "radiusMeters", site.getRadiusMeters()
        ));
        return Result.success(Map.of("id", site.getId()));
    }

    @PostMapping("/sites/{id}")
    public Result<Void> updateSite(@PathVariable Long id, @RequestBody SiteRequest req, HttpServletRequest request) {
        validateSite(req);
        CheckinSite site = checkinSiteRepository.findById(id)
                .orElseThrow(() -> new BusinessException("打卡点不存在"));
        site.setSiteName(req.name.trim());
        site.setSiteType(normalizeSiteType(req.type));
        site.setLatitude(req.latitude);
        site.setLongitude(req.longitude);
        site.setRadiusMeters(req.radiusMeters != null ? req.radiusMeters : 300);
        site.setDetailAddress(req.address);
        checkinSiteRepository.save(site);
        audit(request, "SITE_UPDATE", "CHECKIN_SITE", site.getId(), Map.of(
                "name", site.getSiteName(),
                "type", site.getSiteType(),
                "radiusMeters", site.getRadiusMeters()
        ));
        return Result.success();
    }

    @PostMapping("/sites/{id}/disable")
    public Result<Void> disableSite(@PathVariable Long id, HttpServletRequest request) {
        CheckinSite site = checkinSiteRepository.findById(id)
                .orElseThrow(() -> new BusinessException("打卡点不存在"));
        site.setStatus("DISABLED");
        checkinSiteRepository.save(site);
        audit(request, "SITE_DISABLE", "CHECKIN_SITE", site.getId(), Map.of(
                "name", site.getSiteName(),
                "type", site.getSiteType()
        ));
        return Result.success();
    }

    @PostMapping("/sites/{id}/enable")
    public Result<Void> enableSite(@PathVariable Long id, HttpServletRequest request) {
        CheckinSite site = checkinSiteRepository.findById(id)
                .orElseThrow(() -> new BusinessException("打卡点不存在"));
        site.setStatus("ACTIVE");
        checkinSiteRepository.save(site);
        audit(request, "SITE_ENABLE", "CHECKIN_SITE", site.getId(), Map.of(
                "name", site.getSiteName(),
                "type", site.getSiteType()
        ));
        return Result.success();
    }

    @GetMapping("/class/session/{sessionId}/attendance")
    public Result<Map<String, Object>> sessionAttendance(@PathVariable Long sessionId, HttpServletRequest request) {
        ClassSession session = classSessionRepository.findById(sessionId)
                .orElseThrow(() -> new BusinessException("课堂场次不存在"));
        assertCanManageClass(request, session.getClassId());
        List<User> users = session.getClassId() != null
                ? userRepository.findByClassIdAndRoleAndStatus(session.getClassId(), "STUDENT", "ACTIVE")
                : students(request);
        Map<Long, CheckinRecord> records = checkinRecordRepository.findBySessionId(sessionId)
                .stream()
                .collect(Collectors.toMap(CheckinRecord::getUserId, Function.identity(), (a, b) -> a));
        List<Map<String, Object>> rows = users.stream().map(u -> {
            CheckinRecord r = records.get(u.getId());
            boolean ok = r != null && "SUCCESS".equals(r.getStatus());
            return Map.<String, Object>of(
                    "userId", u.getId(),
                    "name", u.getRealName(),
                    "studentId", u.getStudentId(),
                    "checked", ok,
                    "time", r != null ? fmtTime(r.getCheckinTime()) : "",
                    "status", r == null ? "未签到" : r.getStatus(),
                    "failReason", r != null && r.getFailReason() != null ? r.getFailReason() : ""
            );
        }).toList();
        long present = rows.stream().filter(r -> Boolean.TRUE.equals(r.get("checked"))).count();
        return Result.success(Map.of(
                "sessionId", session.getId(),
                "courseName", session.getCourseName(),
                "teacherName", session.getTeacherName(),
                "total", rows.size(),
                "present", present,
                "absent", Math.max(0, rows.size() - present),
                "rate", rate(present, rows.size()),
                "records", rows
        ));
    }

    @GetMapping("/intern/monitor")
    public Result<List<Map<String, Object>>> internMonitor(HttpServletRequest request) {
        LocalDate today = LocalDate.now();
        LocalDateTime start = today.atStartOfDay();
        LocalDateTime end = start.plusDays(1);
        List<User> managedStudents = students(request);
        Set<Long> managedIds = managedStudents.stream().map(User::getId).collect(Collectors.toSet());
        Map<Long, CheckinRecord> records = checkinRecordRepository
                .findByCheckinTypeAndCheckinTimeBetween("INTERNSHIP", start, end)
                .stream()
                .filter(r -> managedIds.contains(r.getUserId()))
                .collect(Collectors.toMap(CheckinRecord::getUserId, Function.identity(), (a, b) -> a));
        Map<Long, InternLog> logs = internLogRepository.findByWorkDate(today)
                .stream()
                .filter(log -> managedIds.contains(log.getUserId()))
                .collect(Collectors.toMap(InternLog::getUserId, Function.identity(), (a, b) -> a));
        return Result.success(managedStudents.stream().map(u -> {
            CheckinRecord record = records.get(u.getId());
            InternLog log = logs.get(u.getId());
            boolean leaveExempt = hasApprovedLeave(u.getId(), start, end);
            boolean ok = record != null && "SUCCESS".equals(record.getStatus());
            return Map.<String, Object>of(
                    "userId", u.getId(),
                    "name", u.getRealName(),
                    "studentId", u.getStudentId(),
                    "company", log != null ? log.getCompanyName() : "",
                    "checked", ok || leaveExempt,
                    "time", record != null ? fmtTime(record.getCheckinTime()) : "",
                    "log", log != null ? log.getContent() : "",
                    "status", leaveExempt ? "免打卡" : ok ? "正常" : "未打卡"
            );
        }).toList());
    }

    @GetMapping("/intern/logs")
    public Result<List<Map<String, Object>>> internLogs(HttpServletRequest request) {
        Map<Long, User> users = students(request).stream()
                .collect(Collectors.toMap(User::getId, Function.identity()));
        return Result.success(internLogRepository.findAllByOrderByWorkDateDesc().stream()
                .filter(log -> users.containsKey(log.getUserId()))
                .map(log -> {
                    User u = users.get(log.getUserId());
                    return Map.<String, Object>of(
                            "id", log.getId(),
                            "userId", log.getUserId(),
                            "name", u != null ? u.getRealName() : "",
                            "studentId", u != null ? u.getStudentId() : "",
                            "company", log.getCompanyName(),
                            "workDate", log.getWorkDate() != null ? log.getWorkDate().toString() : "",
                            "content", log.getContent(),
                            "mentorReview", log.getMentorReview() != null ? log.getMentorReview() : "",
                            "reviewed", log.getMentorReview() != null && !log.getMentorReview().isBlank()
                    );
                }).toList());
    }

    @PostMapping("/intern/log/{id}/review")
    public Result<Void> reviewInternLog(@PathVariable Long id, @RequestBody ReviewRequest req, HttpServletRequest request) {
        InternLog log = internLogRepository.findById(id)
                .orElseThrow(() -> new BusinessException("实习日志不存在"));
        assertCanManageStudent(request, log.getUserId());
        String comment = req.comment == null ? "" : req.comment.trim();
        if (comment.length() < 2 || comment.length() > 300) {
            throw new BusinessException("评阅意见需填写2-300字");
        }
        Long reviewerId = currentUserId(request);
        log.setMentorReview(comment);
        log.setMentorId(reviewerId);
        internLogRepository.save(log);
        audit(request, "INTERN_LOG_REVIEW", "INTERN_LOG", log.getId(), Map.of(
                "studentId", log.getUserId(),
                "workDate", log.getWorkDate() != null ? log.getWorkDate().toString() : "",
                "company", log.getCompanyName() != null ? log.getCompanyName() : ""
        ));
        Notification notification = notificationRepository.save(Notification.builder()
                .receiverId(log.getUserId())
                .senderId(reviewerId)
                .notifyType("INFO")
                .title("实习日志已评阅")
                .content("你的 " + log.getWorkDate() + " 实习日志已收到评阅意见。")
                .relatedType("INTERN_LOG")
                .relatedId(log.getId())
                .read(false)
                .createdAt(LocalDateTime.now())
                .build());
        notificationStreamService.publish(notification);
        return Result.success();
    }

    @GetMapping("/alerts")
    public Result<List<Map<String, Object>>> alerts(HttpServletRequest request) {
        return Result.success(scopedWarnings(request)
                .stream()
                .map(n -> Map.<String, Object>of(
                        "id", n.getId(),
                        "time", n.getCreatedAt() != null ? fmtTime(n.getCreatedAt()) : "",
                        "title", n.getTitle(),
                        "content", n.getContent(),
                        "type", n.getRelatedType() != null ? n.getRelatedType() : "",
                        "level", isRed(n) ? "RED" : "YELLOW",
                        "handled", Boolean.TRUE.equals(n.getRead())
                )).toList());
    }

    @PostMapping("/alerts/{id}/handle")
    public Result<Void> handleAlert(@PathVariable Long id, HttpServletRequest request) {
        Notification notification = notificationRepository.findById(id)
                .orElseThrow(() -> new BusinessException("预警不存在"));
        assertCanManageNotification(request, notification);
        notification.setRead(true);
        notification.setReadAt(LocalDateTime.now());
        notificationRepository.save(notification);
        audit(request, "ALERT_HANDLE", "NOTIFICATION", notification.getId(), Map.of(
                "title", notification.getTitle(),
                "receiverId", notification.getReceiverId()
        ));
        return Result.success();
    }

    @PostMapping("/alerts/generate")
    public Result<Map<String, Object>> generateAlerts(HttpServletRequest request) {
        LocalDate today = LocalDate.now();
        LocalDateTime start = today.atStartOfDay();
        LocalDateTime end = start.plusDays(1);
        int created = 0;
        created += generateMissingAlerts("DORM", "查寝未打卡", start, end, request);
        created += generateMissingAlerts("INTERNSHIP", "实习未打卡", start, end, request);
        return Result.success(Map.of("created", created));
    }

    @GetMapping("/leave/list")
    public Result<List<Map<String, Object>>> leaveList(HttpServletRequest request) {
        Map<Long, User> users = students(request).stream()
                .collect(Collectors.toMap(User::getId, Function.identity()));
        return Result.success(leaveRequestRepository.findAllByOrderByCreatedAtDesc().stream()
                .filter(l -> users.containsKey(l.getUserId()))
                .map(l -> {
                    User u = users.get(l.getUserId());
                    return Map.<String, Object>of(
                            "id", l.getId(),
                            "name", u != null ? u.getRealName() : "",
                            "studentId", u != null ? u.getStudentId() : "",
                            "type", l.getLeaveType(),
                            "start", fmtDate(l.getStartTime()),
                            "end", fmtDate(l.getEndTime()),
                            "reason", l.getReason(),
                            "status", l.getStatus()
                    );
                }).toList());
    }

    @PostMapping("/leave/{id}/approve")
    public Result<Void> approveLeave(@PathVariable Long id, @RequestBody ReviewRequest req, HttpServletRequest request) {
        reviewLeave(id, "APPROVED", req.comment, currentUserId(request), request);
        return Result.success();
    }

    @PostMapping("/leave/{id}/reject")
    public Result<Void> rejectLeave(@PathVariable Long id, @RequestBody ReviewRequest req, HttpServletRequest request) {
        reviewLeave(id, "REJECTED", req.comment, currentUserId(request), request);
        return Result.success();
    }

    @PostMapping("/appeal/{id}/review")
    public Result<Void> reviewAppeal(@PathVariable Long id, @RequestBody ReviewRequest req, HttpServletRequest request) {
        CheckinRecord record = checkinRecordRepository.findById(id)
                .orElseThrow(() -> new BusinessException("打卡记录不存在"));
        assertCanManageStudent(request, record.getUserId());
        if (!"PENDING".equals(record.getAppealStatus())) {
            throw new BusinessException("该申诉已处理");
        }
        boolean approved = req.approved != null && req.approved;
        record.setAppealStatus(approved ? "APPROVED" : "REJECTED");
        record.setAppealReviewComment(req.comment);
        record.setAppealReviewedAt(LocalDateTime.now());
        if (approved) {
            record.setStatus("SUCCESS");
            record.setFailReason(req.comment != null && !req.comment.isBlank() ? req.comment : "申诉通过，已修正为有效打卡");
        }
        checkinRecordRepository.save(record);
        audit(request, "APPEAL_REVIEW", "CHECKIN_RECORD", record.getId(), Map.of(
                "approved", approved,
                "studentId", record.getUserId(),
                "checkinType", record.getCheckinType() != null ? record.getCheckinType() : ""
        ));
        Notification notification = notificationRepository.save(Notification.builder()
                .receiverId(record.getUserId())
                .notifyType("APPROVAL")
                .title("打卡申诉" + (approved ? "已通过" : "已驳回"))
                .content((approved ? "你的打卡申诉已通过，记录已修正为有效打卡。" : "你的打卡申诉已驳回。")
                        + (req.comment != null && !req.comment.isBlank() ? "审核意见：" + req.comment : ""))
                .relatedType("APPEAL")
                .relatedId(record.getId())
                .read(false)
                .createdAt(LocalDateTime.now())
                .build());
        notificationStreamService.publish(notification);
        return Result.success();
    }

    @GetMapping("/appeals")
    public Result<List<Map<String, Object>>> appeals(@RequestParam(defaultValue = "PENDING") String status,
                                                     HttpServletRequest request) {
        Map<Long, User> users = students(request).stream()
                .collect(Collectors.toMap(User::getId, Function.identity()));
        return Result.success(checkinRecordRepository.findByAppealStatusOrderByAppealedAtDesc(status)
                .stream()
                .filter(r -> users.containsKey(r.getUserId()))
                .map(r -> {
                    User u = users.get(r.getUserId());
                    return Map.<String, Object>of(
                            "id", r.getId(),
                            "name", u != null ? u.getRealName() : "",
                            "studentId", u != null ? u.getStudentId() : "",
                            "type", r.getCheckinType(),
                            "time", fmtDate(r.getCheckinTime()),
                            "failReason", r.getFailReason() != null ? r.getFailReason() : "",
                            "appealReason", r.getAppealReason() != null ? r.getAppealReason() : "",
                            "appealStatus", r.getAppealStatus() != null ? r.getAppealStatus() : "",
                            "appealedAt", fmtDate(r.getAppealedAt())
                    );
                }).toList());
    }

    @GetMapping("/audit/logs")
    public Result<List<Map<String, Object>>> auditLogs(
            @RequestParam(defaultValue = "50") int limit,
            HttpServletRequest request) {
        User current = currentUser(request);
        int size = Math.max(1, Math.min(limit, 100));
        List<AuditLog> logs = "ADMIN".equals(current.getRole())
                ? auditLogRepository.findAllByOrderByCreatedAtDesc(PageRequest.of(0, size))
                : auditLogRepository.findByUserIdOrderByCreatedAtDesc(current.getId(), PageRequest.of(0, size));
        Map<Long, User> users = userRepository.findAll().stream()
                .collect(Collectors.toMap(User::getId, Function.identity()));
        return Result.success(logs.stream().map(log -> {
            User user = log.getUserId() != null ? users.get(log.getUserId()) : null;
            Map<String, Object> row = new java.util.LinkedHashMap<>();
            row.put("id", log.getId());
            row.put("operatorId", log.getUserId() != null ? log.getUserId() : 0);
            row.put("operatorName", user != null ? user.getRealName() : "系统");
            row.put("action", log.getAction());
            row.put("actionLabel", actionLabel(log.getAction()));
            row.put("resource", log.getResource());
            row.put("resourceId", log.getResourceId() != null ? log.getResourceId() : 0);
            row.put("detail", log.getDetail() != null ? log.getDetail() : "{}");
            row.put("ipAddress", log.getIpAddress() != null ? log.getIpAddress() : "");
            row.put("userAgent", log.getUserAgent() != null ? log.getUserAgent() : "");
            row.put("createdAt", fmtDate(log.getCreatedAt()));
            return row;
        }).toList());
    }

    @GetMapping("/report/weekly")
    public Result<Map<String, Object>> weeklyReport(HttpServletRequest request) {
        LocalDateTime end = LocalDate.now().plusDays(1).atStartOfDay();
        LocalDateTime start = end.minusDays(7);
        Set<Long> managedIds = students(request).stream().map(User::getId).collect(Collectors.toSet());
        List<CheckinRecord> records = checkinRecordRepository.findByCheckinTimeBetweenOrderByCheckinTimeDesc(start, end);
        Map<String, Long> success = records.stream()
                .filter(r -> managedIds.contains(r.getUserId()))
                .filter(r -> "SUCCESS".equals(r.getStatus()))
                .collect(Collectors.groupingBy(CheckinRecord::getCheckinType, Collectors.counting()));
        long denominator = Math.max(1, managedIds.size() * 7L);
        return Result.success(Map.of(
                "dormRate", rate(success.getOrDefault("DORM", 0L), denominator),
                "classRate", rate(success.getOrDefault("CLASS", 0L), denominator),
                "internRate", rate(success.getOrDefault("INTERNSHIP", 0L), denominator),
                "recordCount", records.size()
        ));
    }

    @GetMapping("/report/trend")
    public Result<List<Map<String, Object>>> trendReport(@RequestParam(defaultValue = "7") int days,
                                                         HttpServletRequest request) {
        int size = Math.max(1, Math.min(days, 31));
        Set<Long> managedIds = students(request).stream().map(User::getId).collect(Collectors.toSet());
        long total = Math.max(1, managedIds.size());
        LocalDate startDate = LocalDate.now().minusDays(size - 1L);
        LocalDateTime start = startDate.atStartOfDay();
        LocalDateTime end = LocalDate.now().plusDays(1).atStartOfDay();
        List<CheckinRecord> records = checkinRecordRepository.findByCheckinTimeBetweenOrderByCheckinTimeDesc(start, end)
                .stream()
                .filter(r -> managedIds.contains(r.getUserId()))
                .toList();

        return Result.success(java.util.stream.IntStream.range(0, size)
                .mapToObj(i -> {
                    LocalDate date = startDate.plusDays(i);
                    LocalDateTime dayStart = date.atStartOfDay();
                    LocalDateTime dayEnd = dayStart.plusDays(1);
                    Map<String, Long> counts = records.stream()
                            .filter(r -> r.getCheckinTime() != null
                                    && !r.getCheckinTime().isBefore(dayStart)
                                    && r.getCheckinTime().isBefore(dayEnd)
                                    && "SUCCESS".equals(r.getStatus()))
                            .collect(Collectors.groupingBy(CheckinRecord::getCheckinType, Collectors.counting()));
                    long dorm = counts.getOrDefault("DORM", 0L);
                    long clazz = counts.getOrDefault("CLASS", 0L);
                    long intern = counts.getOrDefault("INTERNSHIP", 0L);
                    return Map.<String, Object>of(
                            "date", date.toString(),
                            "dormCount", dorm,
                            "classCount", clazz,
                            "internCount", intern,
                            "dormRate", rate(dorm, total),
                            "classRate", rate(clazz, total),
                            "internRate", rate(intern, total)
                    );
                })
                .toList());
    }

    @GetMapping("/report/weekly/export")
    public ResponseEntity<byte[]> exportWeeklyReport(HttpServletRequest request) {
        LocalDateTime end = LocalDate.now().plusDays(1).atStartOfDay();
        LocalDateTime start = end.minusDays(7);
        return exportCheckinReport(start, end, "weekly-checkin-report-" + LocalDate.now() + ".csv", request);
    }

    @GetMapping("/report/monthly/export")
    public ResponseEntity<byte[]> exportMonthlyReport(HttpServletRequest request) {
        LocalDateTime end = LocalDate.now().plusDays(1).atStartOfDay();
        LocalDateTime start = LocalDate.now().withDayOfMonth(1).atStartOfDay();
        return exportCheckinReport(start, end, "monthly-checkin-report-" + LocalDate.now() + ".csv", request);
    }

    @GetMapping("/intern/logs/export")
    public ResponseEntity<byte[]> exportInternLogs(HttpServletRequest request) {
        Map<Long, User> users = students(request).stream()
                .collect(Collectors.toMap(User::getId, Function.identity()));
        StringBuilder csv = new StringBuilder("\uFEFF");
        csv.append("日期,姓名,学号,实习单位,日志内容,导师评阅\n");
        for (InternLog log : internLogRepository.findAllByOrderByWorkDateDesc()) {
            User user = users.get(log.getUserId());
            if (user == null) continue;
            csv.append(csvCell(log.getWorkDate() != null ? log.getWorkDate().toString() : ""))
                    .append(',')
                    .append(csvCell(user != null ? user.getRealName() : ""))
                    .append(',')
                    .append(csvCell(user != null ? user.getStudentId() : ""))
                    .append(',')
                    .append(csvCell(log.getCompanyName()))
                    .append(',')
                    .append(csvCell(log.getContent()))
                    .append(',')
                    .append(csvCell(log.getMentorReview() != null ? log.getMentorReview() : ""))
                    .append('\n');
        }
        return csvResponse(csv, "intern-log-archive-" + LocalDate.now() + ".csv");
    }

    private ResponseEntity<byte[]> exportCheckinReport(LocalDateTime start, LocalDateTime end, String filename,
                                                       HttpServletRequest request) {
        Map<Long, User> users = students(request).stream()
                .collect(Collectors.toMap(User::getId, Function.identity()));
        List<CheckinRecord> records = checkinRecordRepository.findByCheckinTimeBetweenOrderByCheckinTimeDesc(start, end)
                .stream()
                .filter(r -> users.containsKey(r.getUserId()))
                .toList();

        StringBuilder csv = new StringBuilder("\uFEFF");
        csv.append("姓名,学号,类型,时间,状态,定位通过,人脸通过,失败原因\n");
        for (CheckinRecord r : records) {
            User user = users.get(r.getUserId());
            csv.append(csvCell(user != null ? user.getRealName() : ""))
                    .append(',')
                    .append(csvCell(user != null ? user.getStudentId() : ""))
                    .append(',')
                    .append(csvCell(r.getCheckinType()))
                    .append(',')
                    .append(csvCell(fmtDate(r.getCheckinTime())))
                    .append(',')
                    .append(csvCell(r.getStatus()))
                    .append(',')
                    .append(Boolean.TRUE.equals(r.getLocationPassed()) ? "是" : "否")
                    .append(',')
                    .append(Boolean.TRUE.equals(r.getFacePassed()) ? "是" : "否")
                    .append(',')
                    .append(csvCell(r.getFailReason() != null ? r.getFailReason() : ""))
                    .append('\n');
        }

        return csvResponse(csv, filename);
    }

    private ResponseEntity<byte[]> csvResponse(StringBuilder csv, String filename) {
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + filename + "\"")
                .contentType(new MediaType("text", "csv", StandardCharsets.UTF_8))
                .body(csv.toString().getBytes(StandardCharsets.UTF_8));
    }

    private List<Map<String, Object>> classCheckinRows(Long classId, String type, HttpServletRequest request) {
        LocalDateTime start = LocalDate.now().atStartOfDay();
        LocalDateTime end = start.plusDays(1);
        List<User> users = userRepository.findByClassIdAndRoleAndStatus(classId, "STUDENT", "ACTIVE");
        if (users.isEmpty()) users = students(request);
        Set<Long> managedIds = students(request).stream().map(User::getId).collect(Collectors.toSet());
        users = users.stream().filter(u -> managedIds.contains(u.getId())).toList();
        List<Long> ids = users.stream().map(User::getId).toList();
        Map<Long, CheckinRecord> records = ids.isEmpty()
                ? Map.of()
                : checkinRecordRepository.findTodayByUsers(ids, type, start, end).stream()
                        .collect(Collectors.toMap(CheckinRecord::getUserId, Function.identity(), (a, b) -> a));
        return users.stream().map(u -> {
            CheckinRecord r = records.get(u.getId());
            boolean leaveExempt = hasApprovedLeave(u.getId(), start, end);
            boolean ok = r != null && "SUCCESS".equals(r.getStatus());
            return Map.<String, Object>of(
                    "userId", u.getId(),
                    "name", u.getRealName(),
                    "studentId", u.getStudentId(),
                    "checked", ok || leaveExempt,
                    "time", r != null ? fmtTime(r.getCheckinTime()) : "",
                    "status", leaveExempt ? "免打卡" : r == null ? "未打卡" : r.getStatus(),
                    "failReason", r != null && r.getFailReason() != null ? r.getFailReason() : ""
            );
        }).toList();
    }

    private List<User> students(HttpServletRequest request) {
        User current = currentUser(request);
        if ("ADMIN".equals(current.getRole())) {
            return userRepository.findByRoleAndStatus("STUDENT", "ACTIVE");
        }
        if ("INSTRUCTOR".equals(current.getRole()) && current.getClassId() != null) {
            return userRepository.findByClassIdAndRoleAndStatus(current.getClassId(), "STUDENT", "ACTIVE");
        }
        return List.of();
    }

    private List<User> studentsForSession(ClassSession session) {
        return session.getClassId() != null
                ? userRepository.findByClassIdAndRoleAndStatus(session.getClassId(), "STUDENT", "ACTIVE")
                : userRepository.findByRoleAndStatus("STUDENT", "ACTIVE");
    }

    private List<Notification> scopedWarnings(HttpServletRequest request) {
        Set<Long> managedIds = students(request).stream().map(User::getId).collect(Collectors.toSet());
        if (managedIds.isEmpty()) return List.of();
        return notificationRepository.findByNotifyTypeOrderByCreatedAtDesc("WARNING")
                .stream()
                .filter(n -> n.getReceiverId() != null && managedIds.contains(n.getReceiverId()))
                .toList();
    }

    private User currentUser(HttpServletRequest request) {
        Long userId = currentUserId(request);
        return userRepository.findById(userId)
                .orElseThrow(() -> new BusinessException(401, "登录用户不存在"));
    }

    private Long scopedClassIdForRead(HttpServletRequest request, Long requestedClassId) {
        User current = currentUser(request);
        if ("ADMIN".equals(current.getRole())) return requestedClassId;
        if (!"INSTRUCTOR".equals(current.getRole()) || current.getClassId() == null) {
            throw new BusinessException(403, "当前账号无可管理班级");
        }
        if (requestedClassId != null && !current.getClassId().equals(requestedClassId)) {
            throw new BusinessException(403, "无权查看该班级数据");
        }
        return current.getClassId();
    }

    private Long scopedClassIdForCreate(HttpServletRequest request, Long requestedClassId) {
        User current = currentUser(request);
        if ("ADMIN".equals(current.getRole())) return requestedClassId;
        if (!"INSTRUCTOR".equals(current.getRole()) || current.getClassId() == null) {
            throw new BusinessException(403, "当前账号无可管理班级");
        }
        if (requestedClassId != null && !current.getClassId().equals(requestedClassId)) {
            throw new BusinessException(403, "无权为该班级发起签到");
        }
        return current.getClassId();
    }

    private void assertCanManageClass(HttpServletRequest request, Long classId) {
        User current = currentUser(request);
        if ("ADMIN".equals(current.getRole())) return;
        if (!"INSTRUCTOR".equals(current.getRole()) || current.getClassId() == null) {
            throw new BusinessException(403, "当前账号无可管理班级");
        }
        if (classId == null || !current.getClassId().equals(classId)) {
            throw new BusinessException(403, "无权操作该班级数据");
        }
    }

    private void assertCanManageStudent(HttpServletRequest request, Long studentId) {
        User student = userRepository.findById(studentId)
                .orElseThrow(() -> new BusinessException("学生不存在"));
        assertCanManageStudent(request, student);
    }

    private void assertCanManageStudent(HttpServletRequest request, User student) {
        User current = currentUser(request);
        if ("ADMIN".equals(current.getRole())) return;
        if (!"INSTRUCTOR".equals(current.getRole()) || current.getClassId() == null) {
            throw new BusinessException(403, "当前账号无可管理学生");
        }
        if (!"STUDENT".equals(student.getRole()) || !current.getClassId().equals(student.getClassId())) {
            throw new BusinessException(403, "无权操作该学生数据");
        }
    }

    private void assertCanManageNotification(HttpServletRequest request, Notification notification) {
        if (notification.getReceiverId() == null) {
            throw new BusinessException(403, "无权操作该预警");
        }
        assertCanManageStudent(request, notification.getReceiverId());
    }

    private void notifyClassSessionStudents(ClassSession session) {
        List<User> receivers = studentsForSession(session);
        if (receivers.isEmpty()) return;

        LocalDateTime now = LocalDateTime.now();
        List<Notification> notifications = receivers.stream()
                .map(user -> Notification.builder()
                        .receiverId(user.getId())
                        .notifyType("REMINDER")
                        .title("课堂签到已发起")
                        .content(session.getCourseName() + " 已开放" + signModeLabel(session.getSignMode()) + "，请在 "
                                + fmtTime(session.getSignStartTime()) + " - " + fmtTime(session.getSignEndTime())
                                + " 内完成签到。")
                        .relatedType("CLASS_SESSION")
                        .relatedId(session.getId())
                        .read(false)
                        .createdAt(now)
                        .build())
                .toList();
        notificationStreamService.publishAll(notificationRepository.saveAll(notifications));
    }

    private void validateClassSession(ClassSessionRequest req) {
        if (req == null) throw new BusinessException("请填写课堂场次信息");
        if (req.courseName == null || req.courseName.trim().length() < 2) {
            throw new BusinessException("课程名称至少2个字");
        }
        if (req.teacherName == null || req.teacherName.trim().length() < 2) {
            throw new BusinessException("教师名称至少2个字");
        }
        if (req.siteId == null) throw new BusinessException("请选择课堂打卡点");
        String signMode = req.signMode == null || req.signMode.isBlank() ? "LOCATION" : req.signMode.toUpperCase();
        if (!List.of("MANUAL", "QR", "LOCATION", "PHOTO").contains(signMode)) {
            throw new BusinessException("签到方式不正确");
        }
        if (req.startTime == null || req.endTime == null || req.signStartTime == null || req.signEndTime == null) {
            throw new BusinessException("请填写上课和签到时间");
        }
        if (!req.endTime.isAfter(req.startTime)) {
            throw new BusinessException("下课时间必须晚于上课时间");
        }
        if (req.signStartTime.isBefore(req.startTime.minusMinutes(30)) || req.signEndTime.isAfter(req.endTime.plusMinutes(30))) {
            throw new BusinessException("签到窗口需在课堂前后30分钟范围内");
        }
        if (!req.signEndTime.isAfter(req.signStartTime)) {
            throw new BusinessException("签到结束时间必须晚于开始时间");
        }
    }

    private void validateSite(SiteRequest req) {
        if (req == null) throw new BusinessException("请填写打卡点信息");
        if (req.name == null || req.name.trim().length() < 2) {
            throw new BusinessException("打卡点名称至少2个字");
        }
        String siteType = normalizeSiteType(req.type == null ? "" : req.type);
        if (!List.of("DORM", "CLASSROOM", "INTERNSHIP").contains(siteType)) {
            throw new BusinessException("打卡点类型不正确");
        }
        if (req.latitude == null || req.longitude == null) {
            throw new BusinessException("请填写经纬度");
        }
        if (req.radiusMeters != null && (req.radiusMeters < 20 || req.radiusMeters > 5000)) {
            throw new BusinessException("打卡半径需在20-5000米之间");
        }
    }

    private String normalizeSiteType(String type) {
        return switch (type.toUpperCase()) {
            case "CLASS", "CLASSROOM" -> "CLASSROOM";
            case "INTERN", "INTERNSHIP" -> "INTERNSHIP";
            case "DORM" -> "DORM";
            default -> type.toUpperCase();
        };
    }

    private String signModeLabel(String mode) {
        return switch (mode == null ? "LOCATION" : mode.toUpperCase()) {
            case "MANUAL" -> "普通签到";
            case "QR" -> "二维码签到";
            case "PHOTO" -> "拍照签到";
            default -> "位置签到";
        };
    }

    private void reviewLeave(Long id, String status, String comment, Long reviewerId, HttpServletRequest request) {
        LeaveRequest leave = leaveRequestRepository.findById(id)
                .orElseThrow(() -> new BusinessException("请假申请不存在"));
        assertCanManageStudent(request, leave.getUserId());
        if (!"PENDING".equals(leave.getStatus())) {
            throw new BusinessException("该请假申请已处理");
        }
        leave.setStatus(status);
        leave.setReviewComment(comment);
        leave.setReviewerId(reviewerId);
        leave.setReviewedAt(LocalDateTime.now());
        leaveRequestRepository.save(leave);
        audit(request, "LEAVE_" + status, "LEAVE_REQUEST", leave.getId(), Map.of(
                "studentId", leave.getUserId(),
                "leaveType", leave.getLeaveType() != null ? leave.getLeaveType() : "",
                "status", status
        ));
        Notification notification = notificationRepository.save(Notification.builder()
                .receiverId(leave.getUserId())
                .senderId(reviewerId)
                .notifyType("APPROVAL")
                .title("请假申请" + ("APPROVED".equals(status) ? "已通过" : "已驳回"))
                .content(("APPROVED".equals(status) ? "你的请假申请已通过。" : "你的请假申请已驳回。")
                        + (comment != null && !comment.isBlank() ? "审批意见：" + comment : ""))
                .relatedType("LEAVE")
                .relatedId(leave.getId())
                .read(false)
                .createdAt(LocalDateTime.now())
                .build());
        notificationStreamService.publish(notification);
    }

    private int generateMissingAlerts(String type, String title, LocalDateTime start, LocalDateTime end,
                                      HttpServletRequest request) {
        List<User> users = students(request);
        List<Long> ids = users.stream().map(User::getId).toList();
        Map<Long, CheckinRecord> records = ids.isEmpty()
                ? Map.of()
                : checkinRecordRepository.findTodayByUsers(ids, type, start, end).stream()
                        .filter(r -> "SUCCESS".equals(r.getStatus()))
                        .collect(Collectors.toMap(CheckinRecord::getUserId, Function.identity(), (a, b) -> a));
        int created = 0;
        for (User user : users) {
            if (records.containsKey(user.getId()) || hasApprovedLeave(user.getId(), start, end)) continue;
            boolean exists = notificationRepository.existsByReceiverIdAndNotifyTypeAndTitleAndCreatedAtBetween(
                    user.getId(), "WARNING", title, start, end);
            if (exists) continue;
            Notification notification = notificationRepository.save(Notification.builder()
                    .receiverId(user.getId())
                    .notifyType("WARNING")
                    .title(title)
                    .content(user.getRealName() + " 今日" + title + "，请辅导员及时核实。")
                    .relatedType(type)
                    .read(false)
                    .createdAt(LocalDateTime.now())
                    .build());
            notificationStreamService.publish(notification);
            created++;
        }
        return created;
    }

    private boolean hasApprovedLeave(Long userId, LocalDateTime start, LocalDateTime end) {
        return !leaveRequestRepository
                .findByUserIdAndStatusAndStartTimeLessThanEqualAndEndTimeGreaterThanEqual(
                        userId, "APPROVED", end, start)
                .isEmpty();
    }

    private double haversine(double lat1, double lng1, double lat2, double lng2) {
        final double r = 6_371_000;
        double dLat = Math.toRadians(lat2 - lat1);
        double dLng = Math.toRadians(lng2 - lng1);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                * Math.sin(dLng / 2) * Math.sin(dLng / 2);
        return r * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    }

    private Map<String, Object> classQrData(Long sessionId, long expiresInSeconds) {
        ClassSession session = classSessionRepository.findById(sessionId)
                .orElseThrow(() -> new BusinessException("课堂场次不存在"));
        CheckinSite site = checkinSiteRepository.findById(session.getSiteId())
                .orElseThrow(() -> new BusinessException("课堂打卡点不存在"));
        long expiresIn = Math.max(10, Math.min(expiresInSeconds, 120));
        String token = jwtUtils.generateClassQrToken(site.getId(), session.getId(), expiresIn);
        return Map.of(
                "token", token,
                "siteId", site.getId(),
                "sessionId", session.getId(),
                "siteName", site.getSiteName(),
                "courseName", session.getCourseName(),
                "teacherName", session.getTeacherName(),
                "expiresInSeconds", expiresIn,
                "expiresAt", java.time.Instant.now().plusSeconds(expiresIn).toString()
        );
    }

    private Long currentUserId(HttpServletRequest request) {
        String header = request.getHeader("Authorization");
        if (header == null || !header.startsWith("Bearer ")) throw new BusinessException(401, "未登录");
        return jwtUtils.getUserId(header.substring(7));
    }

    private void audit(HttpServletRequest request, String action, String resource, Long resourceId, Map<String, Object> detail) {
        auditLogService.record(currentUserId(request), action, resource, resourceId, detail, request);
    }

    private String actionLabel(String action) {
        return switch (action == null ? "" : action) {
            case "CLASS_MANUAL_CHECKIN" -> "普通签到代录";
            case "CLASS_SESSION_CREATE" -> "发起课堂签到";
            case "CLASS_SESSION_CLOSE" -> "关闭课堂签到";
            case "SITE_CREATE" -> "新增打卡点";
            case "SITE_UPDATE" -> "编辑打卡点";
            case "SITE_DISABLE" -> "停用打卡点";
            case "SITE_ENABLE" -> "启用打卡点";
            case "INTERN_LOG_REVIEW" -> "评阅实习日志";
            case "ALERT_HANDLE" -> "处理预警";
            case "APPEAL_REVIEW" -> "审核打卡申诉";
            case "LEAVE_APPROVED" -> "批准请假";
            case "LEAVE_REJECTED" -> "驳回请假";
            default -> action != null ? action : "";
        };
    }

    private boolean isRed(Notification notification) {
        return notification.getTitle().contains("严重") || notification.getContent().contains("连续");
    }

    private double rate(long numerator, long denominator) {
        if (denominator <= 0) return 0;
        return Math.round(numerator * 1000.0 / denominator) / 10.0;
    }

    private String fmtTime(LocalDateTime time) {
        return time == null ? "" : time.format(DateTimeFormatter.ofPattern("HH:mm"));
    }

    private String fmtDate(LocalDateTime time) {
        return time == null ? "" : time.format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm"));
    }

    private String csvCell(String value) {
        String escaped = value == null ? "" : value.replace("\"", "\"\"");
        return "\"" + escaped + "\"";
    }

    public record ReviewRequest(Boolean approved, String comment) {}

    public record ManualCheckinRequest(Long userId, Long siteId, Long sessionId) {}

    public record MobileClassSessionRequest(
            String mode,
            String courseName,
            String teacherName,
            Long classId,
            Long siteId,
            Integer durationMinutes) {}

    public record ClassSessionRequest(
            String courseName,
            String teacherName,
            Long classId,
            Long siteId,
            LocalDateTime startTime,
            LocalDateTime endTime,
            LocalDateTime signStartTime,
            LocalDateTime signEndTime,
            String signMode) {}

    public record SiteRequest(
            String name,
            String type,
            BigDecimal latitude,
            BigDecimal longitude,
            Integer radiusMeters,
            String address) {}
}
