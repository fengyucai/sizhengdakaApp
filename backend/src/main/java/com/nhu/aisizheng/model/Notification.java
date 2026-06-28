package com.nhu.aisizheng.model;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

/**
 * 通知/预警实体
 */
@Entity
@Table(name = "notification")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Notification {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "receiver_id", nullable = false)
    private Long receiverId;

    @Column(name = "sender_id")
    private Long senderId;

    @Column(name = "notify_type", nullable = false, length = 30)
    private String notifyType;

    @Column(nullable = false, length = 100)
    private String title;

    @Column(nullable = false, columnDefinition = "NVARCHAR(MAX)")
    private String content;

    @Column(name = "related_type", length = 20)
    private String relatedType;

    @Column(name = "related_id")
    private Long relatedId;

    @Column(name = "is_read")
    @Builder.Default
    private Boolean read = false;

    @Column(name = "read_at")
    private LocalDateTime readAt;

    @Column(name = "created_at")
    private LocalDateTime createdAt;
}
