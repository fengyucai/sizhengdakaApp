package com.nhu.aisizheng.utils;

import io.jsonwebtoken.*;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Date;
import java.util.Map;
import java.util.UUID;

/**
 * JWT 令牌工具类
 */
@Component
public class JwtUtils {

    private final SecretKey key;
    private final long accessExpire;
    private final long refreshExpire;

    public JwtUtils(
            @Value("${app.jwt.secret}") String secret,
            @Value("${app.jwt.access-token-expire}") long accessExpire,
            @Value("${app.jwt.refresh-token-expire}") long refreshExpire) {
        // 确保密钥 ≥256bit
        String safeSecret = secret.length() < 32
                ? secret + "00000000000000000000000000000000".substring(0, 32 - secret.length())
                : secret;
        this.key = Keys.hmacShaKeyFor(safeSecret.getBytes(StandardCharsets.UTF_8));
        this.accessExpire = accessExpire;
        this.refreshExpire = refreshExpire;
    }

    public String generateAccessToken(Long userId, String role) {
        return generateToken(userId, role, accessExpire);
    }

    public String generateRefreshToken(Long userId, String role) {
        return generateToken(userId, role, refreshExpire);
    }

    public String generateClassQrToken(Long siteId, Long sessionId, long expireSeconds) {
        Date now = new Date();
        return Jwts.builder()
                .claims(Map.of(
                        "purpose", "CLASS_QR",
                        "siteId", siteId,
                        "sessionId", sessionId,
                        "nonce", UUID.randomUUID().toString()))
                .subject("class-qr:" + siteId)
                .issuedAt(now)
                .expiration(new Date(now.getTime() + expireSeconds * 1000))
                .signWith(key)
                .compact();
    }

    private String generateToken(Long userId, String role, long expireSeconds) {
        Date now = new Date();
        return Jwts.builder()
                .claims(Map.of("userId", userId, "role", role))
                .subject(String.valueOf(userId))
                .issuedAt(now)
                .expiration(new Date(now.getTime() + expireSeconds * 1000))
                .signWith(key)
                .compact();
    }

    public Claims parseToken(String token) {
        return Jwts.parser()
                .verifyWith(key)
                .build()
                .parseSignedClaims(token)
                .getPayload();
    }

    public boolean validateToken(String token) {
        try {
            parseToken(token);
            return true;
        } catch (JwtException | IllegalArgumentException e) {
            return false;
        }
    }

    public Long getUserId(String token) {
        return parseToken(token).get("userId", Long.class);
    }

    public Long getClassQrSiteId(String token) {
        Claims claims = parseToken(token);
        if (!"CLASS_QR".equals(claims.get("purpose", String.class))) {
            throw new IllegalArgumentException("二维码类型不正确");
        }
        Object siteId = claims.get("siteId");
        if (siteId instanceof Number number) return number.longValue();
        return Long.valueOf(String.valueOf(siteId));
    }

    public Long getClassQrSessionId(String token) {
        Claims claims = parseToken(token);
        if (!"CLASS_QR".equals(claims.get("purpose", String.class))) {
            throw new IllegalArgumentException("二维码类型不正确");
        }
        Object sessionId = claims.get("sessionId");
        if (sessionId instanceof Number number) return number.longValue();
        return Long.valueOf(String.valueOf(sessionId));
    }
}
