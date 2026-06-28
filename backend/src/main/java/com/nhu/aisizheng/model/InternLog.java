package com.nhu.aisizheng.model;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * 实习日志实体
 */
@Entity
@Table(name = "intern_log")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class InternLog {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(name = "company_name", nullable = false, length = 100)
    private String companyName;

    @Column(name = "work_date", nullable = false)
    private LocalDate workDate;

    @Column(nullable = false, columnDefinition = "NVARCHAR(MAX)")
    private String content;

    @Column(name = "mentor_review", columnDefinition = "NVARCHAR(MAX)")
    private String mentorReview;

    @Column(name = "mentor_id")
    private Long mentorId;

    @Column(name = "created_at")
    private LocalDateTime createdAt;
}
