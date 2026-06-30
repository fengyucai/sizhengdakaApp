package com.nhu.aisizheng.controller;

import com.nhu.aisizheng.common.BusinessException;
import com.nhu.aisizheng.common.Result;
import com.nhu.aisizheng.model.Notification;
import com.nhu.aisizheng.repository.NotificationRepository;
import com.nhu.aisizheng.utils.JwtUtils;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

/**
 * 学生端通知消息接口
 */
@RestController
@RequestMapping("/notifications")
@RequiredArgsConstructor
@Tag(name = "通知消息", description = "学生端消息列表、已读和全部已读")
public class NotificationController {

    private final NotificationRepository notificationRepository;
    private final JwtUtils jwtUtils;

    @GetMapping
    public Result<Map<String, Object>> list(HttpServletRequest request) {
        Long userId = currentUserId(request);
        List<Map<String, Object>> items = notificationRepository.findByReceiverIdOrderByCreatedAtDesc(userId)
                .stream()
                .map(this::toMap)
                .toList();
        return Result.success(Map.of(
                "unreadCount", notificationRepository.countByReceiverIdAndRead(userId, false),
                "items", items
        ));
    }

    @PostMapping("/{id}/read")
    public Result<Void> markRead(@PathVariable Long id, HttpServletRequest request) {
        Long userId = currentUserId(request);
        Notification notification = notificationRepository.findById(id)
                .orElseThrow(() -> new BusinessException("通知不存在"));
        if (!userId.equals(notification.getReceiverId())) {
            throw new BusinessException("无权操作该通知");
        }
        notification.setRead(true);
        notification.setReadAt(LocalDateTime.now());
        notificationRepository.save(notification);
        return Result.success();
    }

    @PostMapping("/read-all")
    public Result<Void> markAllRead(HttpServletRequest request) {
        Long userId = currentUserId(request);
        List<Notification> notifications = notificationRepository.findByReceiverIdOrderByCreatedAtDesc(userId);
        LocalDateTime now = LocalDateTime.now();
        notifications.stream()
                .filter(n -> !Boolean.TRUE.equals(n.getRead()))
                .forEach(n -> {
                    n.setRead(true);
                    n.setReadAt(now);
                });
        notificationRepository.saveAll(notifications);
        return Result.success();
    }

    private Map<String, Object> toMap(Notification notification) {
        return Map.of(
                "id", notification.getId(),
                "type", notification.getNotifyType(),
                "title", notification.getTitle(),
                "content", notification.getContent(),
                "relatedType", notification.getRelatedType() != null ? notification.getRelatedType() : "",
                "relatedId", notification.getRelatedId() != null ? notification.getRelatedId() : 0,
                "read", Boolean.TRUE.equals(notification.getRead()),
                "createdAt", notification.getCreatedAt() != null ? notification.getCreatedAt().toString() : ""
        );
    }

    private Long currentUserId(HttpServletRequest request) {
        String token = request.getHeader("Authorization").replace("Bearer ", "");
        return jwtUtils.getUserId(token);
    }
}
