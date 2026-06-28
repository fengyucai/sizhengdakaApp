package com.nhu.aisizheng.model;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

/**
 * 请假申请实体
 */
@Entity
@Table(name = "leave_request")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class LeaveRequest {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(name = "leave_type", nullable = false, length = 20)
    private String leaveType;

    @Column(name = "start_time", nullable = false)
    private LocalDateTime startTime;

    @Column(name = "end_time", nullable = false)
    private LocalDateTime endTime;

    @Column(nullable = false, columnDefinition = "NVARCHAR(MAX)")
    private String reason;

    @Column(name = "attachment_url", length = 255)
    private String attachmentUrl;

    @Column(length = 20)
    @Builder.Default
    private String status = "PENDING";

    @Column(name = "reviewer_id")
    private Long reviewerId;

    @Column(name = "review_comment", columnDefinition = "NVARCHAR(MAX)")
    private String reviewComment;

    @Column(name = "reviewed_at")
    private LocalDateTime reviewedAt;

    @Column(name = "created_at")
    private LocalDateTime createdAt;
}
