package com.nhu.aisizheng.controller;

import com.nhu.aisizheng.common.Result;
import lombok.extern.slf4j.Slf4j;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

/**
 * 位置服务 — 逆地理编码
 */
@Slf4j
@RestController
@RequestMapping("/location")
public class LocationController {

    /**
     * 根据经纬度返回详细地址信息
     * 客户端优先使用浏览器本地Nominatim API，此接口作为服务端fallback
     */
    @GetMapping("/reverse")
    public Result<Map<String, Object>> reverseGeocode(
            @RequestParam double lat,
            @RequestParam double lng) {

        // 返回经纬度+区域判断
        String region = guessRegion(lat, lng);

        return Result.success(Map.of(
                "latitude", lat,
                "longitude", lng,
                "region", region,
                "display", String.format("%s (%.5f, %.5f)", region, lat, lng)
        ));
    }

    /** 根据坐标推断大致区域 — 覆盖全国主要城市 */
    private String guessRegion(double lat, double lng) {
        // 衡阳 — 南华大学
        if (lat > 26.88 && lat < 26.91 && lng > 112.55 && lng < 112.60)
            return "湖南省衡阳市蒸湘区 — 南华大学红湘校区";
        if (lat > 26.84 && lat < 26.88 && lng > 112.56 && lng < 112.60)
            return "湖南省衡阳市蒸湘区";
        if (lat > 26.80 && lat < 27.00 && lng > 112.50 && lng < 112.70)
            return "湖南省衡阳市";
        // 长沙
        if (lat > 28.15 && lat < 28.30 && lng > 112.90 && lng < 113.10)
            return "湖南省长沙市岳麓区";
        if (lat > 28.10 && lat < 28.35 && lng > 112.85 && lng < 113.15)
            return "湖南省长沙市";
        // 株洲
        if (lat > 27.75 && lat < 27.95 && lng > 113.05 && lng < 113.25)
            return "湖南省株洲市";
        // 湘潭
        if (lat > 27.78 && lat < 27.95 && lng > 112.85 && lng < 113.05)
            return "湖南省湘潭市";
        // 北京
        if (lat > 39.80 && lat < 40.10 && lng > 116.20 && lng < 116.60)
            return "北京市";
        // 上海
        if (lat > 31.10 && lat < 31.40 && lng > 121.30 && lng < 121.60)
            return "上海市";
        // 广州
        if (lat > 23.05 && lat < 23.25 && lng > 113.20 && lng < 113.40)
            return "广东省广州市";
        // 深圳
        if (lat > 22.45 && lat < 22.65 && lng > 113.85 && lng < 114.15)
            return "广东省深圳市";
        // 武汉
        if (lat > 30.45 && lat < 30.70 && lng > 114.20 && lng < 114.45)
            return "湖北省武汉市";
        // 成都
        if (lat > 30.55 && lat < 30.75 && lng > 103.95 && lng < 104.20)
            return "四川省成都市";
        // 重庆
        if (lat > 29.45 && lat < 29.65 && lng > 106.45 && lng < 106.65)
            return "重庆市";
        // 南京
        if (lat > 31.95 && lat < 32.15 && lng > 118.70 && lng < 118.90)
            return "江苏省南京市";
        // 杭州
        if (lat > 30.15 && lat < 30.35 && lng > 120.10 && lng < 120.30)
            return "浙江省杭州市";
        // 西安
        if (lat > 34.15 && lat < 34.35 && lng > 108.85 && lng < 109.05)
            return "陕西省西安市";
        // 郑州
        if (lat > 34.70 && lat < 34.85 && lng > 113.55 && lng < 113.75)
            return "河南省郑州市";
        // 其他湖南省内
        if (lat > 25.00 && lat < 30.00 && lng > 109.00 && lng < 114.50)
            return "湖南省";
        // 其他广东省内
        if (lat > 20.00 && lat < 25.50 && lng > 109.50 && lng < 117.50)
            return "广东省";
        return String.format("(%.4f, %.4f) 附近", lat, lng);
    }
}
