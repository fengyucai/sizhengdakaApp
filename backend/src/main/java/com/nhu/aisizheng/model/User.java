package com.nhu.aisizheng.model;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

/**
 * 用户实体
 */
@Entity
@Table(name = "sys_user")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "student_id", nullable = false, unique = true, length = 20)
    private String studentId;

    @Column(name = "real_name", nullable = false, length = 50)
    private String realName;

    @Column(name = "password_hash", nullable = false, length = 128)
    private String passwordHash;

    /** STUDENT / INSTRUCTOR / ADMIN */
    @Column(nullable = false, length = 20)
    private String role;

    @Column(name = "class_id")
    private Long classId;

    @Column(length = 20)
    private String phone;

    @Column(name = "face_registered")
    private Boolean faceRegistered;

    @Column(name = "face_group_id", length = 50)
    private String faceGroupId;

    /** ACTIVE / SUSPENDED / GRADUATED */
    @Column(length = 10)
    @Builder.Default
    private String status = "ACTIVE";

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;
}
