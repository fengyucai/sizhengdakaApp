package com.nhu.aisizheng.service;

import com.nhu.aisizheng.model.Notification;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.io.IOException;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;

@Slf4j
@Service
public class NotificationStreamService {

    private static final long TIMEOUT_MILLIS = 30L * 60L * 1000L;

    private final Map<Long, CopyOnWriteArrayList<SseEmitter>> emitters = new ConcurrentHashMap<>();

    public SseEmitter subscribe(Long userId) {
        SseEmitter emitter = new SseEmitter(TIMEOUT_MILLIS);
        emitters.computeIfAbsent(userId, ignored -> new CopyOnWriteArrayList<>()).add(emitter);

        emitter.onCompletion(() -> remove(userId, emitter));
        emitter.onTimeout(() -> remove(userId, emitter));
        emitter.onError(error -> remove(userId, emitter));

        send(userId, emitter, "connected", Map.of(
                "type", "CONNECTED",
                "serverTime", LocalDateTime.now().toString()
        ));
        return emitter;
    }

    public void publish(Notification notification) {
        if (notification == null || notification.getReceiverId() == null) return;
        publish(notification.getReceiverId(), "notification", toMap(notification));
    }

    public void publishAll(List<Notification> notifications) {
        if (notifications == null || notifications.isEmpty()) return;
        notifications.forEach(this::publish);
    }

    private void publish(Long userId, String eventName, Map<String, Object> payload) {
        List<SseEmitter> userEmitters = emitters.get(userId);
        if (userEmitters == null || userEmitters.isEmpty()) return;
        for (SseEmitter emitter : userEmitters) {
            send(userId, emitter, eventName, payload);
        }
    }

    private void send(Long userId, SseEmitter emitter, String eventName, Map<String, Object> payload) {
        try {
            emitter.send(SseEmitter.event()
                    .name(eventName)
                    .data(payload));
        } catch (IOException | IllegalStateException e) {
            remove(userId, emitter);
            log.debug("SSE通知推送连接已移除 userId={}", userId, e);
        }
    }

    private void remove(Long userId, SseEmitter emitter) {
        List<SseEmitter> userEmitters = emitters.get(userId);
        if (userEmitters == null) return;
        userEmitters.remove(emitter);
        if (userEmitters.isEmpty()) {
            emitters.remove(userId);
        }
    }

    private Map<String, Object> toMap(Notification notification) {
        return Map.of(
                "id", notification.getId(),
                "type", notification.getNotifyType(),
                "title", notification.getTitle(),
                "content", notification.getContent(),
                "relatedType", notification.getRelatedType() != null ? notification.getRelatedType() : "",
                "relatedId", notification.getRelatedId() != null ? notification.getRelatedId() : 0,
                "read", Boolean.TRUE.equals(notification.getRead()),
                "createdAt", notification.getCreatedAt() != null ? notification.getCreatedAt().toString() : ""
        );
    }
}
