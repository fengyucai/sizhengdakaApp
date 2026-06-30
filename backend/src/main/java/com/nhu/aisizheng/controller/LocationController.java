package com.nhu.aisizheng.controller;

import com.nhu.aisizheng.common.Result;
import com.nhu.aisizheng.service.BaiduMapService;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.extern.slf4j.Slf4j;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

/**
 * 位置服务 — 逆地理编码
 */
@Slf4j
@RestController
@RequestMapping("/location")
@RequiredArgsConstructor
@Tag(name = "位置服务", description = "逆地理编码和地址解析")
public class LocationController {

    private final BaiduMapService baiduMapService;

    /**
     * 根据经纬度返回详细地址信息
     * 使用百度地图逆地理编码返回省、市、区、街道、详细地址和周边POI。
     */
    @GetMapping("/reverse")
    public Result<Map<String, Object>> reverseGeocode(
            @RequestParam double lat,
            @RequestParam double lng) {
        return Result.success(baiduMapService.reverseGeocode(lat, lng));
    }

    /**
     * 百度地图地址解析。配置 BAIDU_MAP_AK 后可用于打卡点坐标校准。
     */
    @GetMapping("/geocode")
    public Result<Map<String, Object>> geocode(
            @RequestParam String address,
            @RequestParam(required = false) String city) {
        return Result.success(baiduMapService.geocode(address, city));
    }

}
