package com.nhu.aisizheng.utils;

import java.math.BigDecimal;

/**
 * GPS定位工具类 — Haversine公式计算球面距离
 */
public final class GeoUtils {

    private static final double EARTH_RADIUS_METERS = 6_371_000;

    private GeoUtils() {}

    /**
     * 计算两点间球面距离（米）
     */
    public static double haversineDistance(
            double lat1, double lon1, double lat2, double lon2) {
        double dLat = Math.toRadians(lat2 - lat1);
        double dLon = Math.toRadians(lon2 - lon1);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                 + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                 * Math.sin(dLon / 2) * Math.sin(dLon / 2);
        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return EARTH_RADIUS_METERS * c;
    }

    public static double haversineDistance(
            BigDecimal lat1, BigDecimal lon1,
            BigDecimal lat2, BigDecimal lon2) {
        return haversineDistance(
                lat1.doubleValue(), lon1.doubleValue(),
                lat2.doubleValue(), lon2.doubleValue());
    }

    /**
     * 判断是否在电子围栏范围内
     */
    public static boolean isWithinFence(
            double userLat, double userLon,
            double fenceLat, double fenceLon,
            double radiusMeters) {
        return haversineDistance(userLat, userLon, fenceLat, fenceLon) <= radiusMeters;
    }

    public static boolean isWithinFence(
            BigDecimal userLat, BigDecimal userLon,
            BigDecimal fenceLat, BigDecimal fenceLon,
            double radiusMeters) {
        return isWithinFence(
                userLat.doubleValue(), userLon.doubleValue(),
                fenceLat.doubleValue(), fenceLon.doubleValue(),
                radiusMeters);
    }
}
