package com.nhu.aisizheng.config;

import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Configuration;

@Data
@Configuration
@ConfigurationProperties(prefix = "app.tencent-cloud")
public class TencentCloudConfig {
    private String secretId = "";
    private String secretKey = "";
    private String appId = "";
    private String region = "ap-guangzhou";
    private String faceGroup = "dorm_checkin";
}
