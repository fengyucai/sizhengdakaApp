package com.nhu.aisizheng.model;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 打卡点实体
 */
@Entity
@Table(name = "checkin_site")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CheckinSite {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "site_name", nullable = false, length = 100)
    private String siteName;

    /** DORM / CLASSROOM / INTERNSHIP */
    @Column(name = "site_type", nullable = false, length = 20)
    private String siteType;

    @Column(nullable = false, precision = 10, scale = 7)
    private BigDecimal latitude;

    @Column(nullable = false, precision = 10, scale = 7)
    private BigDecimal longitude;

    @Column(name = "radius_meters")
    @Builder.Default
    private Integer radiusMeters = 300;

    @Column(name = "detail_address", length = 255)
    private String detailAddress;

    @Column(length = 10)
    @Builder.Default
    private String status = "ACTIVE";

    @Column(name = "created_at")
    private LocalDateTime createdAt;
}
