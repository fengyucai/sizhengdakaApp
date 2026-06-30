package com.nhu.aisizheng.controller;

import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDateTime;
import java.util.Map;

/**
 * 健康检查接口
 */
@RestController
@Tag(name = "健康检查", description = "后端服务运行状态")
public class HealthController {

    @GetMapping("/actuator/health")
    public Map<String, Object> health() {
        return Map.of(
                "status", "UP",
                "service", "AI思政打卡APP",
                "version", "1.0.0",
                "timestamp", LocalDateTime.now().toString()
        );
    }
}
