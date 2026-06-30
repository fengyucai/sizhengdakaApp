package com.nhu.aisizheng.model;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

/**
 * 管理端关键操作审计日志。
 */
@Entity
@Table(name = "audit_log")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AuditLog {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id")
    private Long userId;

    @Column(nullable = false, length = 50)
    private String action;

    @Column(nullable = false, length = 50)
    private String resource;

    @Column(name = "resource_id")
    private Long resourceId;

    @Column(columnDefinition = "NVARCHAR(MAX)")
    private String detail;

    @Column(name = "ip_address", length = 45)
    private String ipAddress;

    @Column(name = "user_agent", length = 255)
    private String userAgent;

    @Column(name = "created_at")
    private LocalDateTime createdAt;
}
