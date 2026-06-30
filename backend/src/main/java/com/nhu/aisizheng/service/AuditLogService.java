package com.nhu.aisizheng.service;

import com.nhu.aisizheng.model.AuditLog;
import com.nhu.aisizheng.repository.AuditLogRepository;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.Map;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class AuditLogService {

    private final AuditLogRepository auditLogRepository;

    public void record(
            Long userId,
            String action,
            String resource,
            Long resourceId,
            Map<String, Object> detail,
            HttpServletRequest request) {
        try {
            auditLogRepository.save(AuditLog.builder()
                    .userId(userId)
                    .action(action)
                    .resource(resource)
                    .resourceId(resourceId)
                    .detail(toJson(detail))
                    .ipAddress(clientIp(request))
                    .userAgent(truncate(request != null ? request.getHeader("User-Agent") : null, 255))
                    .createdAt(LocalDateTime.now())
                    .build());
        } catch (Exception e) {
            log.warn("审计日志写入失败 action={}, resource={}, resourceId={}", action, resource, resourceId, e);
        }
    }

    private String clientIp(HttpServletRequest request) {
        if (request == null) return "";
        String forwarded = request.getHeader("X-Forwarded-For");
        if (forwarded != null && !forwarded.isBlank()) {
            return truncate(forwarded.split(",")[0].trim(), 45);
        }
        String realIp = request.getHeader("X-Real-IP");
        if (realIp != null && !realIp.isBlank()) {
            return truncate(realIp, 45);
        }
        return truncate(request.getRemoteAddr(), 45);
    }

    private String toJson(Map<String, Object> detail) {
        if (detail == null || detail.isEmpty()) return "{}";
        return detail.entrySet().stream()
                .map(entry -> "\"" + escape(entry.getKey()) + "\":" + jsonValue(entry.getValue()))
                .collect(Collectors.joining(",", "{", "}"));
    }

    private String jsonValue(Object value) {
        if (value == null) return "null";
        if (value instanceof Number || value instanceof Boolean) return value.toString();
        return "\"" + escape(String.valueOf(value)) + "\"";
    }

    private String escape(String value) {
        return value == null ? "" : value
                .replace("\\", "\\\\")
                .replace("\"", "\\\"")
                .replace("\r", "\\r")
                .replace("\n", "\\n");
    }

    private String truncate(String value, int maxLength) {
        if (value == null) return "";
        return value.length() <= maxLength ? value : value.substring(0, maxLength);
    }
}
