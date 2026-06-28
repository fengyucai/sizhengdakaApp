package com.nhu.aisizheng.model;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 打卡记录实体
 */
@Entity
@Table(name = "checkin_record")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CheckinRecord {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(name = "site_id", nullable = false)
    private Long siteId;

    @Column(name = "session_id")
    private Long sessionId;

    /** DORM / CLASS / INTERNSHIP */
    @Column(name = "checkin_type", nullable = false, length = 20)
    private String checkinType;

    @Column(name = "checkin_time", nullable = false)
    private LocalDateTime checkinTime;

    @Column(precision = 10, scale = 7)
    private BigDecimal latitude;

    @Column(precision = 10, scale = 7)
    private BigDecimal longitude;

    @Column(name = "face_score", precision = 5, scale = 2)
    private BigDecimal faceScore;

    @Column(name = "face_passed")
    private Boolean facePassed;

    @Column(name = "location_passed")
    private Boolean locationPassed;

    @Column(name = "liveness_passed")
    private Boolean livenessPassed;

    /** SUCCESS / FAILED / APPEALED */
    @Column(length = 20)
    @Builder.Default
    private String status = "SUCCESS";

    @Column(name = "device_info", length = 255)
    private String deviceInfo;

    @Column(name = "ip_address", length = 45)
    private String ipAddress;

    @Column(name = "fail_reason", length = 100)
    private String failReason;

    @Column(name = "created_at")
    private LocalDateTime createdAt;
}
