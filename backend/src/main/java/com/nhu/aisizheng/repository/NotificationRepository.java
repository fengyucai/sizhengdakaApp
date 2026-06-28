package com.nhu.aisizheng.repository;

import com.nhu.aisizheng.model.Notification;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.time.LocalDateTime;

@Repository
public interface NotificationRepository extends JpaRepository<Notification, Long> {

    List<Notification> findByReceiverIdOrderByCreatedAtDesc(Long receiverId);

    List<Notification> findByNotifyTypeOrderByCreatedAtDesc(String notifyType);

    long countByReceiverIdAndRead(Long receiverId, Boolean read);

    long countByNotifyTypeAndRead(String notifyType, Boolean read);

    boolean existsByReceiverIdAndNotifyTypeAndTitleAndCreatedAtBetween(
            Long receiverId, String notifyType, String title, LocalDateTime start, LocalDateTime end);
}
