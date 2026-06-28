package com.nhu.aisizheng.controller;

import com.nhu.aisizheng.common.BusinessException;
import com.nhu.aisizheng.common.Result;
import com.nhu.aisizheng.model.CheckinRecord;
import com.nhu.aisizheng.model.ClassSession;
import com.nhu.aisizheng.model.InternLog;
import com.nhu.aisizheng.model.LeaveRequest;
import com.nhu.aisizheng.model.Notification;
import com.nhu.aisizheng.model.User;
import com.nhu.aisizheng.repository.CheckinRecordRepository;
import com.nhu.aisizheng.repository.ClassSessionRepository;
import com.nhu.aisizheng.repository.InternLogRepository;
import com.nhu.aisizheng.repository.LeaveRequestRepository;
import com.nhu.aisizheng.repository.NotificationRepository;
import com.nhu.aisizheng.repository.UserRepository;
import com.nhu.aisizheng.utils.JwtUtils;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

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

    public record ReviewRequest(Boolean approved, String comment) {}
}
