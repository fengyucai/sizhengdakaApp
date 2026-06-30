package com.nhu.aisizheng.controller;

import com.nhu.aisizheng.common.BusinessException;
import com.nhu.aisizheng.common.Result;
import com.nhu.aisizheng.model.LeaveRequest;
import com.nhu.aisizheng.model.Notification;
import com.nhu.aisizheng.repository.LeaveRequestRepository;
import com.nhu.aisizheng.repository.NotificationRepository;
import com.nhu.aisizheng.utils.JwtUtils;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Map;

/**
 * 学生端请假申请接口
 */
@RestController
@RequestMapping("/leave")
@RequiredArgsConstructor
@Tag(name = "学生请假", description = "学生提交、查询和取消请假申请")
public class LeaveController {

    private static final List<String> ALLOWED_TYPES = List.of("SICK", "PERSONAL", "ACADEMIC");

    private final LeaveRequestRepository leaveRequestRepository;
    private final NotificationRepository notificationRepository;
    private final JwtUtils jwtUtils;

    @PostMapping("/apply")
    public Result<Map<String, Object>> apply(@RequestBody ApplyRequest req, HttpServletRequest request) {
        Long userId = currentUserId(request);
        validate(req);
        if (hasOverlap(userId, "PENDING", req.startTime, req.endTime)
                || hasOverlap(userId, "APPROVED", req.startTime, req.endTime)) {
            throw new BusinessException("该时间段已有请假申请，请勿重复提交");
        }

        LeaveRequest leave = LeaveRequest.builder()
                .userId(userId)
                .leaveType(req.leaveType)
                .startTime(req.startTime)
                .endTime(req.endTime)
                .reason(req.reason.trim())
                .attachmentUrl(req.attachmentUrl)
                .status("PENDING")
                .createdAt(LocalDateTime.now())
                .build();
        leaveRequestRepository.save(leave);

        notificationRepository.save(Notification.builder()
                .receiverId(userId)
                .notifyType("APPROVAL")
                .title("请假申请已提交")
                .content("你的请假申请已提交，等待辅导员审批。")
                .relatedType("LEAVE")
                .relatedId(leave.getId())
                .read(false)
                .createdAt(LocalDateTime.now())
                .build());

        return Result.success(toMap(leave));
    }

    @GetMapping("/list")
    public Result<List<Map<String, Object>>> list(HttpServletRequest request) {
        Long userId = currentUserId(request);
        return Result.success(leaveRequestRepository.findByUserIdOrderByCreatedAtDesc(userId)
                .stream()
                .map(this::toMap)
                .toList());
    }

    @PostMapping("/{id}/cancel")
    public Result<Void> cancel(@PathVariable Long id, HttpServletRequest request) {
        Long userId = currentUserId(request);
        LeaveRequest leave = leaveRequestRepository.findById(id)
                .orElseThrow(() -> new BusinessException("请假申请不存在"));
        if (!userId.equals(leave.getUserId())) {
            throw new BusinessException("无权操作该请假申请");
        }
        if (!"PENDING".equals(leave.getStatus())) {
            throw new BusinessException("只有待审批申请可以取消");
        }
        leave.setStatus("CANCELLED");
        leaveRequestRepository.save(leave);
        return Result.success();
    }

    private void validate(ApplyRequest req) {
        if (req == null) {
            throw new BusinessException("请填写请假申请信息");
        }
        if (req.startTime == null || req.endTime == null) {
            throw new BusinessException("请填写请假开始和结束时间");
        }
        if (!ALLOWED_TYPES.contains(req.leaveType)) {
            throw new BusinessException("请假类型不正确");
        }
        if (!req.endTime.isAfter(req.startTime)) {
            throw new BusinessException("结束时间必须晚于开始时间");
        }
        if (req.startTime.isBefore(LocalDateTime.now().minusHours(1))) {
            throw new BusinessException("开始时间不能早于当前时间太久");
        }
        String reason = req.reason == null ? "" : req.reason.trim();
        if (reason.isBlank()) {
            throw new BusinessException("请填写请假原因");
        }
    }

    private boolean hasOverlap(Long userId, String status, LocalDateTime start, LocalDateTime end) {
        return !leaveRequestRepository
                .findByUserIdAndStatusAndStartTimeLessThanEqualAndEndTimeGreaterThanEqual(userId, status, end, start)
                .isEmpty();
    }

    private Map<String, Object> toMap(LeaveRequest leave) {
        return Map.of(
                "id", leave.getId(),
                "type", leave.getLeaveType(),
                "typeLabel", typeLabel(leave.getLeaveType()),
                "start", fmt(leave.getStartTime()),
                "end", fmt(leave.getEndTime()),
                "reason", leave.getReason(),
                "status", leave.getStatus(),
                "statusLabel", statusLabel(leave.getStatus()),
                "reviewComment", leave.getReviewComment() != null ? leave.getReviewComment() : "",
                "createdAt", fmt(leave.getCreatedAt())
        );
    }

    private String typeLabel(String type) {
        return switch (type) {
            case "SICK" -> "病假";
            case "PERSONAL" -> "事假";
            case "ACADEMIC" -> "公假/教学活动";
            default -> type;
        };
    }

    private String statusLabel(String status) {
        return switch (status) {
            case "PENDING" -> "待审批";
            case "APPROVED" -> "已通过";
            case "REJECTED" -> "已驳回";
            case "CANCELLED" -> "已取消";
            default -> status;
        };
    }

    private String fmt(LocalDateTime time) {
        return time == null ? "" : time.format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm"));
    }

    private Long currentUserId(HttpServletRequest request) {
        String header = request.getHeader("Authorization");
        if (header == null || !header.startsWith("Bearer ")) throw new BusinessException(401, "未登录");
        return jwtUtils.getUserId(header.substring(7));
    }

    public record ApplyRequest(
            @NotBlank String leaveType,
            @NotNull LocalDateTime startTime,
            @NotNull LocalDateTime endTime,
            @NotBlank String reason,
            String attachmentUrl) {}
}
