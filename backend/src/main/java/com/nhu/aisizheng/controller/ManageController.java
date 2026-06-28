package com.nhu.aisizheng.controller;

import com.nhu.aisizheng.common.BusinessException;
import com.nhu.aisizheng.common.Result;
import com.nhu.aisizheng.model.CheckinRecord;
import com.nhu.aisizheng.model.CheckinSite;
import com.nhu.aisizheng.model.ClassSession;
import com.nhu.aisizheng.model.InternLog;
import com.nhu.aisizheng.model.LeaveRequest;
import com.nhu.aisizheng.model.Notification;
import com.nhu.aisizheng.model.User;
import com.nhu.aisizheng.repository.CheckinRecordRepository;
import com.nhu.aisizheng.repository.CheckinSiteRepository;
import com.nhu.aisizheng.repository.ClassSessionRepository;
import com.nhu.aisizheng.repository.InternLogRepository;
import com.nhu.aisizheng.repository.LeaveRequestRepository;
import com.nhu.aisizheng.repository.NotificationRepository;
import com.nhu.aisizheng.repository.UserRepository;
import com.nhu.aisizheng.utils.JwtUtils;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * 管理端基础接口。
 */
@RestController
@RequestMapping("/manage")
@RequiredArgsConstructor
public class ManageController {

    private final UserRepository userRepository;
    private final CheckinSiteRepository checkinSiteRepository;
    private final CheckinRecordRepository checkinRecordRepository;
    private final ClassSessionRepository classSessionRepository;
    private final InternLogRepository internLogRepository;
    private final LeaveRequestRepository leaveRequestRepository;
    private final NotificationRepository notificationRepository;
    private final JwtUtils jwtUtils;

    @GetMapping("/dashboard")
    public Result<Map<String, Object>> dashboard() {
        LocalDateTime start = LocalDate.now().atStartOfDay();
        LocalDateTime end = start.plusDays(1);
        long total = students().size();
        Map<String, Long> counts = checkinRecordRepository
                .findByCheckinTimeBetweenOrderByCheckinTimeDesc(start, end)
                .stream()
                .filter(r -> "SUCCESS".equals(r.getStatus()))
                .collect(Collectors.groupingBy(CheckinRecord::getCheckinType, Collectors.counting()));
        long alerts = notificationRepository.countByNotifyTypeAndRead("WARNING", false);
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

    @GetMapping("/class/{classId}/dorm-today")
    public Result<List<Map<String, Object>>> dormToday(@PathVariable Long classId) {
        return Result.success(classCheckinRows(classId, "DORM"));
    }

    @GetMapping("/class/{classId}/attendance")
    public Result<Map<String, Object>> attendance(@PathVariable Long classId) {
        List<Map<String, Object>> records = classCheckinRows(classId, "CLASS");
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
    public Result<List<Map<String, Object>>> classSessions(@RequestParam(required = false) Long classId) {
        LocalDateTime start = LocalDate.now().atStartOfDay();
        LocalDateTime end = start.plusDays(1);
        List<ClassSession> sessions = classId != null
                ? classSessionRepository.findByClassIdAndStatusAndStartTimeBetweenOrderByStartTimeAsc(classId, "ACTIVE", start, end)
                : classSessionRepository.findByStatusAndSignEndTimeGreaterThanEqualOrderByStartTimeAsc("ACTIVE", LocalDateTime.now());
        return Result.success(sessions.stream().map(s -> Map.<String, Object>of(
                "id", s.getId(),
                "courseName", s.getCourseName(),
                "teacherName", s.getTeacherName(),
                "classId", s.getClassId() != null ? s.getClassId() : 0,
                "siteId", s.getSiteId(),
                "startTime", fmtDate(s.getStartTime()),
                "endTime", fmtDate(s.getEndTime()),
                "signStartTime", fmtDate(s.getSignStartTime()),
                "signEndTime", fmtDate(s.getSignEndTime()),
                "active", !LocalDateTime.now().isBefore(s.getSignStartTime())
                        && !LocalDateTime.now().isAfter(s.getSignEndTime())
        )).toList());
    }

    @PostMapping("/class/session")
    public Result<Map<String, Object>> createClassSession(@RequestBody ClassSessionRequest req) {
        validateClassSession(req);
        CheckinSite site = checkinSiteRepository.findById(req.siteId)
                .orElseThrow(() -> new BusinessException("课堂打卡点不存在"));
        if (!"CLASSROOM".equals(site.getSiteType()) || !"ACTIVE".equals(site.getStatus())) {
            throw new BusinessException("请选择启用中的课堂打卡点");
        }
        ClassSession session = ClassSession.builder()
                .courseName(req.courseName.trim())
                .teacherName(req.teacherName.trim())
                .classId(req.classId)
                .siteId(req.siteId)
                .startTime(req.startTime)
                .endTime(req.endTime)
                .signStartTime(req.signStartTime)
                .signEndTime(req.signEndTime)
                .status("ACTIVE")
                .createdAt(LocalDateTime.now())
                .build();
        classSessionRepository.save(session);
        return Result.success(Map.of("id", session.getId()));
    }

    @PostMapping("/class/session/{id}/close")
    public Result<Void> closeClassSession(@PathVariable Long id) {
        ClassSession session = classSessionRepository.findById(id)
                .orElseThrow(() -> new BusinessException("课堂场次不存在"));
        session.setStatus("CLOSED");
        classSessionRepository.save(session);
        return Result.success();
    }

    @GetMapping("/sites")
    public Result<List<Map<String, Object>>> manageSites(@RequestParam(required = false) String type) {
        List<CheckinSite> sites = type == null || type.isBlank()
                ? checkinSiteRepository.findAll()
                : checkinSiteRepository.findBySiteTypeAndStatus(normalizeSiteType(type), "ACTIVE");
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

    @GetMapping("/class/session/{sessionId}/attendance")
    public Result<Map<String, Object>> sessionAttendance(@PathVariable Long sessionId) {
        ClassSession session = classSessionRepository.findById(sessionId)
                .orElseThrow(() -> new BusinessException("课堂场次不存在"));
        List<User> users = session.getClassId() != null
                ? userRepository.findByClassIdAndRoleAndStatus(session.getClassId(), "STUDENT", "ACTIVE")
                : students();
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
    public Result<List<Map<String, Object>>> internMonitor() {
        LocalDate today = LocalDate.now();
        LocalDateTime start = today.atStartOfDay();
        LocalDateTime end = start.plusDays(1);
        Map<Long, CheckinRecord> records = checkinRecordRepository
                .findByCheckinTypeAndCheckinTimeBetween("INTERNSHIP", start, end)
                .stream()
                .collect(Collectors.toMap(CheckinRecord::getUserId, Function.identity(), (a, b) -> a));
        Map<Long, InternLog> logs = internLogRepository.findByWorkDate(today)
                .stream()
                .collect(Collectors.toMap(InternLog::getUserId, Function.identity(), (a, b) -> a));
        return Result.success(students().stream().map(u -> {
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
    public Result<List<Map<String, Object>>> internLogs() {
        Map<Long, User> users = userRepository.findAll().stream()
                .collect(Collectors.toMap(User::getId, Function.identity()));
        return Result.success(internLogRepository.findAllByOrderByWorkDateDesc().stream()
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
        String comment = req.comment == null ? "" : req.comment.trim();
        if (comment.length() < 2 || comment.length() > 300) {
            throw new BusinessException("评阅意见需填写2-300字");
        }
        Long reviewerId = currentUserId(request);
        log.setMentorReview(comment);
        log.setMentorId(reviewerId);
        internLogRepository.save(log);
        notificationRepository.save(Notification.builder()
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
        return Result.success();
    }

    @GetMapping("/alerts")
    public Result<List<Map<String, Object>>> alerts() {
        return Result.success(notificationRepository.findByNotifyTypeOrderByCreatedAtDesc("WARNING")
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
    public Result<Void> handleAlert(@PathVariable Long id) {
        Notification notification = notificationRepository.findById(id)
                .orElseThrow(() -> new BusinessException("预警不存在"));
        notification.setRead(true);
        notification.setReadAt(LocalDateTime.now());
        notificationRepository.save(notification);
        return Result.success();
    }

    @PostMapping("/alerts/generate")
    public Result<Map<String, Object>> generateAlerts() {
        LocalDate today = LocalDate.now();
        LocalDateTime start = today.atStartOfDay();
        LocalDateTime end = start.plusDays(1);
        int created = 0;
        created += generateMissingAlerts("DORM", "查寝未打卡", start, end);
        created += generateMissingAlerts("INTERNSHIP", "实习未打卡", start, end);
        return Result.success(Map.of("created", created));
    }

    @GetMapping("/leave/list")
    public Result<List<Map<String, Object>>> leaveList() {
        Map<Long, User> users = userRepository.findAll().stream()
                .collect(Collectors.toMap(User::getId, Function.identity()));
        return Result.success(leaveRequestRepository.findAllByOrderByCreatedAtDesc().stream()
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
        reviewLeave(id, "APPROVED", req.comment, currentUserId(request));
        return Result.success();
    }

    @PostMapping("/leave/{id}/reject")
    public Result<Void> rejectLeave(@PathVariable Long id, @RequestBody ReviewRequest req, HttpServletRequest request) {
        reviewLeave(id, "REJECTED", req.comment, currentUserId(request));
        return Result.success();
    }

    @PostMapping("/appeal/{id}/review")
    public Result<Void> reviewAppeal(@PathVariable Long id, @RequestBody ReviewRequest req) {
        CheckinRecord record = checkinRecordRepository.findById(id)
                .orElseThrow(() -> new BusinessException("打卡记录不存在"));
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
        notificationRepository.save(Notification.builder()
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
        return Result.success();
    }

    @GetMapping("/appeals")
    public Result<List<Map<String, Object>>> appeals(@RequestParam(defaultValue = "PENDING") String status) {
        Map<Long, User> users = userRepository.findAll().stream()
                .collect(Collectors.toMap(User::getId, Function.identity()));
        return Result.success(checkinRecordRepository.findByAppealStatusOrderByAppealedAtDesc(status)
                .stream()
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

    @GetMapping("/report/weekly")
    public Result<Map<String, Object>> weeklyReport() {
        LocalDateTime end = LocalDate.now().plusDays(1).atStartOfDay();
        LocalDateTime start = end.minusDays(7);
        List<CheckinRecord> records = checkinRecordRepository.findByCheckinTimeBetweenOrderByCheckinTimeDesc(start, end);
        Map<String, Long> success = records.stream()
                .filter(r -> "SUCCESS".equals(r.getStatus()))
                .collect(Collectors.groupingBy(CheckinRecord::getCheckinType, Collectors.counting()));
        long denominator = Math.max(1, students().size() * 7L);
        return Result.success(Map.of(
                "dormRate", rate(success.getOrDefault("DORM", 0L), denominator),
                "classRate", rate(success.getOrDefault("CLASS", 0L), denominator),
                "internRate", rate(success.getOrDefault("INTERNSHIP", 0L), denominator),
                "recordCount", records.size()
        ));
    }

    @GetMapping("/report/trend")
    public Result<List<Map<String, Object>>> trendReport(@RequestParam(defaultValue = "7") int days) {
        int size = Math.max(1, Math.min(days, 31));
        long total = Math.max(1, students().size());
        LocalDate startDate = LocalDate.now().minusDays(size - 1L);
        LocalDateTime start = startDate.atStartOfDay();
        LocalDateTime end = LocalDate.now().plusDays(1).atStartOfDay();
        List<CheckinRecord> records = checkinRecordRepository.findByCheckinTimeBetweenOrderByCheckinTimeDesc(start, end);

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
    public ResponseEntity<byte[]> exportWeeklyReport() {
        LocalDateTime end = LocalDate.now().plusDays(1).atStartOfDay();
        LocalDateTime start = end.minusDays(7);
        return exportCheckinReport(start, end, "weekly-checkin-report-" + LocalDate.now() + ".csv");
    }

    @GetMapping("/report/monthly/export")
    public ResponseEntity<byte[]> exportMonthlyReport() {
        LocalDateTime end = LocalDate.now().plusDays(1).atStartOfDay();
        LocalDateTime start = LocalDate.now().withDayOfMonth(1).atStartOfDay();
        return exportCheckinReport(start, end, "monthly-checkin-report-" + LocalDate.now() + ".csv");
    }

    @GetMapping("/intern/logs/export")
    public ResponseEntity<byte[]> exportInternLogs() {
        Map<Long, User> users = userRepository.findAll().stream()
                .collect(Collectors.toMap(User::getId, Function.identity()));
        StringBuilder csv = new StringBuilder("\uFEFF");
        csv.append("日期,姓名,学号,实习单位,日志内容,导师评阅\n");
        for (InternLog log : internLogRepository.findAllByOrderByWorkDateDesc()) {
            User user = users.get(log.getUserId());
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

    private ResponseEntity<byte[]> exportCheckinReport(LocalDateTime start, LocalDateTime end, String filename) {
        Map<Long, User> users = userRepository.findAll().stream()
                .collect(Collectors.toMap(User::getId, Function.identity()));
        List<CheckinRecord> records = checkinRecordRepository.findByCheckinTimeBetweenOrderByCheckinTimeDesc(start, end);

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

    private List<Map<String, Object>> classCheckinRows(Long classId, String type) {
        LocalDateTime start = LocalDate.now().atStartOfDay();
        LocalDateTime end = start.plusDays(1);
        List<User> users = userRepository.findByClassIdAndRoleAndStatus(classId, "STUDENT", "ACTIVE");
        if (users.isEmpty()) users = students();
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

    private List<User> students() {
        return userRepository.findByRoleAndStatus("STUDENT", "ACTIVE");
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

    private String normalizeSiteType(String type) {
        return switch (type.toUpperCase()) {
            case "CLASS", "CLASSROOM" -> "CLASSROOM";
            case "INTERN", "INTERNSHIP" -> "INTERNSHIP";
            case "DORM" -> "DORM";
            default -> type.toUpperCase();
        };
    }

    private void reviewLeave(Long id, String status, String comment, Long reviewerId) {
        LeaveRequest leave = leaveRequestRepository.findById(id)
                .orElseThrow(() -> new BusinessException("请假申请不存在"));
        if (!"PENDING".equals(leave.getStatus())) {
            throw new BusinessException("该请假申请已处理");
        }
        leave.setStatus(status);
        leave.setReviewComment(comment);
        leave.setReviewerId(reviewerId);
        leave.setReviewedAt(LocalDateTime.now());
        leaveRequestRepository.save(leave);
        notificationRepository.save(Notification.builder()
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
    }

    private int generateMissingAlerts(String type, String title, LocalDateTime start, LocalDateTime end) {
        List<User> users = students();
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
            notificationRepository.save(Notification.builder()
                    .receiverId(user.getId())
                    .notifyType("WARNING")
                    .title(title)
                    .content(user.getRealName() + " 今日" + title + "，请辅导员及时核实。")
                    .relatedType(type)
                    .read(false)
                    .createdAt(LocalDateTime.now())
                    .build());
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

    private Long currentUserId(HttpServletRequest request) {
        String header = request.getHeader("Authorization");
        if (header == null || !header.startsWith("Bearer ")) throw new BusinessException(401, "未登录");
        return jwtUtils.getUserId(header.substring(7));
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

    public record ClassSessionRequest(
            String courseName,
            String teacherName,
            Long classId,
            Long siteId,
            LocalDateTime startTime,
            LocalDateTime endTime,
            LocalDateTime signStartTime,
            LocalDateTime signEndTime) {}
}
