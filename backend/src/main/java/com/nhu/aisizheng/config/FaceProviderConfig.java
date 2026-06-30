package com.nhu.aisizheng.config;

import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Configuration;

@Data
@Configuration
@ConfigurationProperties(prefix = "app.face")
public class FaceProviderConfig {
    private String provider = "BAIDU";
}
