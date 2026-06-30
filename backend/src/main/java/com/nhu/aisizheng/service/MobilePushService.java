package com.nhu.aisizheng.service;

import com.nhu.aisizheng.config.PushProperties;
import com.nhu.aisizheng.model.Notification;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

@Slf4j
@Service
@RequiredArgsConstructor
public class MobilePushService {

    private final PushProperties pushProperties;

    public void push(Notification notification) {
        if (notification == null || notification.getReceiverId() == null) return;
        String provider = pushProperties.providerOrNone();
        if ("NONE".equals(provider)) {
            log.debug("Background push skipped because app.push.provider=NONE notificationId={}", notification.getId());
            return;
        }
        if ("JPUSH".equals(provider)) {
            log.warn("JPUSH provider is configured but SDK integration is not enabled yet. notificationId={}",
                    notification.getId());
            return;
        }
        log.warn("Unsupported push provider [{}]. notificationId={}", provider, notification.getId());
    }
}
