package com.nhu.aisizheng.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "app.push")
public record PushProperties(
        String provider,
        Jpush jpush
) {
    public String providerOrNone() {
        return provider == null || provider.isBlank() ? "NONE" : provider.trim().toUpperCase();
    }

    public record Jpush(
            String appKey,
            String masterSecret,
            boolean production
    ) {}
}
