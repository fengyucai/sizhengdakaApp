package com.nhu.aisizheng;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;
import org.springframework.scheduling.annotation.EnableScheduling;

/**
 * AI思政打卡APP — 后端启动入口
 *
 * @author AI思政开发组
 * @since 2026-06-26
 */
@SpringBootApplication
@EnableScheduling
@ConfigurationPropertiesScan
public class AiSizhengApplication {

    public static void main(String[] args) {
        SpringApplication.run(AiSizhengApplication.class, args);
    }
}
