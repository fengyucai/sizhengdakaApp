package com.nhu.aisizheng.model;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

/**
 * 课堂签到场次实体
 */
@Entity
@Table(name = "class_session")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ClassSession {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "course_name", nullable = false, length = 100)
    private String courseName;

    @Column(name = "teacher_name", nullable = false, length = 50)
    private String teacherName;

    @Column(name = "class_id")
    private Long classId;

    @Column(name = "site_id", nullable = false)
    private Long siteId;

    @Column(name = "start_time", nullable = false)
    private LocalDateTime startTime;

    @Column(name = "end_time", nullable = false)
    private LocalDateTime endTime;

    @Column(name = "sign_start_time", nullable = false)
    private LocalDateTime signStartTime;

    @Column(name = "sign_end_time", nullable = false)
    private LocalDateTime signEndTime;

    @Column(length = 20)
    @Builder.Default
    private String status = "ACTIVE";

    @Column(name = "created_at")
    private LocalDateTime createdAt;
}
