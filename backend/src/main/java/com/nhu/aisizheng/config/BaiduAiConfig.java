package com.nhu.aisizheng.config;

import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Configuration;

/**
 * 百度AI配置属性
 */
@Data
@Configuration
@ConfigurationProperties(prefix = "app.baidu-ai")
public class BaiduAiConfig {
    /** 百度AI AppId */
    private String appId = "";
    /** API Key */
    private String apiKey = "";
    /** Secret Key */
    private String secretKey = "";
    /** 人脸库分组ID */
    private String faceGroup = "dorm_checkin";
}
