package com.nhu.aisizheng.service;

import com.nhu.aisizheng.model.CheckinRecord;
import com.nhu.aisizheng.model.Notification;
import com.nhu.aisizheng.model.User;
import com.nhu.aisizheng.repository.CheckinRecordRepository;
import com.nhu.aisizheng.repository.LeaveRequestRepository;
import com.nhu.aisizheng.repository.NotificationRepository;
import com.nhu.aisizheng.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * 打卡提醒和未打卡预警定时任务。
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AlertScheduler {

    private final UserRepository userRepository;
    private final CheckinRecordRepository checkinRecordRepository;
    private final LeaveRequestRepository leaveRequestRepository;
    private final NotificationRepository notificationRepository;

    @Value("${app.alert.enabled:true}")
    private boolean enabled;

    @Value("${app.alert.dorm-remind-time:21:30}")
    private String dormRemindTime;

    @Value("${app.alert.dorm-deadline:23:00}")
    private String dormDeadline;

    @Value("${app.alert.intern-deadline:18:00}")
    private String internDeadline;

    @Scheduled(cron = "0 */10 * * * *")
    public void runAlerts() {
        if (!enabled) return;
        LocalTime now = LocalTime.now();
        LocalDate today = LocalDate.now();
        LocalDateTime start = today.atStartOfDay();
        LocalDateTime end = start.plusDays(1);

        if (!now.isBefore(LocalTime.parse(dormRemindTime))) {
            createMissingNotifications("DORM", "REMINDER", "查寝打卡提醒",
                    "请在查寝截止时间前完成定位与人脸打卡。", start, end);
        }
        if (!now.isBefore(LocalTime.parse(dormDeadline))) {
            createMissingNotifications("DORM", "WARNING", "查寝未打卡",
                    "今日查寝未打卡，请尽快联系辅导员说明情况。", start, end);
        }
        if (!now.isBefore(LocalTime.parse(internDeadline))) {
            createMissingNotifications("INTERNSHIP", "WARNING", "实习未打卡",
                    "今日实习未打卡，请尽快完成实习打卡和日志上报。", start, end);
        }
    }

    private void createMissingNotifications(
            String checkinType,
            String notifyType,
            String title,
            String content,
            LocalDateTime start,
            LocalDateTime end) {
        List<User> users = userRepository.findByRoleAndStatus("STUDENT", "ACTIVE");
        if (users.isEmpty()) return;
        List<Long> ids = users.stream().map(User::getId).toList();
        Map<Long, CheckinRecord> records = checkinRecordRepository.findTodayByUsers(ids, checkinType, start, end)
                .stream()
                .filter(r -> "SUCCESS".equals(r.getStatus()))
                .collect(Collectors.toMap(CheckinRecord::getUserId, Function.identity(), (a, b) -> a));

        int created = 0;
        for (User user : users) {
            if (records.containsKey(user.getId()) || hasApprovedLeave(user.getId(), start, end)) continue;
            boolean exists = notificationRepository.existsByReceiverIdAndNotifyTypeAndTitleAndCreatedAtBetween(
                    user.getId(), notifyType, title, start, end);
            if (exists) continue;
            notificationRepository.save(Notification.builder()
                    .receiverId(user.getId())
                    .notifyType(notifyType)
                    .title(title)
                    .content(content)
                    .relatedType(checkinType)
                    .read(false)
                    .createdAt(LocalDateTime.now())
                    .build());
            created++;
        }
        if (created > 0) {
            log.info("自动生成{}通知: type={}, count={}", title, checkinType, created);
        }
    }

    private boolean hasApprovedLeave(Long userId, LocalDateTime start, LocalDateTime end) {
        return !leaveRequestRepository
                .findByUserIdAndStatusAndStartTimeLessThanEqualAndEndTimeGreaterThanEqual(
                        userId, "APPROVED", end, start)
                .isEmpty();
    }
}
