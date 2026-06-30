package com.nhu.aisizheng.service;

import com.nhu.aisizheng.common.BusinessException;
import com.nhu.aisizheng.config.BaiduAiConfig;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.util.UriComponentsBuilder;

import java.math.BigDecimal;
import java.net.URI;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * 百度地图Web服务封装。
 */
@Service
@RequiredArgsConstructor
public class BaiduMapService {

    private final BaiduAiConfig config;
    private final RestTemplate restTemplate = new RestTemplate();
    private final ObjectMapper objectMapper = new ObjectMapper();

    public Map<String, Object> geocode(String address, String city) {
        if (config.getMapAk() == null || config.getMapAk().isBlank()) {
            throw new BusinessException("未配置百度地图AK，请设置环境变量 BAIDU_MAP_AK 后重试");
        }
        String cleanAddress = address == null ? "" : address.trim();
        if (cleanAddress.length() < 2) {
            throw new BusinessException("地址至少2个字");
        }

        UriComponentsBuilder builder = UriComponentsBuilder
                .fromHttpUrl("https://api.map.baidu.com/geocoding/v3/")
                .queryParam("address", cleanAddress)
                .queryParam("output", "json")
                .queryParam("ak", config.getMapAk());
        if (city != null && !city.isBlank()) {
            builder.queryParam("city", city.trim());
        }

        URI uri = builder.build(true).toUri();
        Map<String, Object> response = getJson(uri);
        if (response == null) {
            throw new BusinessException("百度地图服务无响应");
        }
        Number status = (Number) response.get("status");
        if (status == null || status.intValue() != 0) {
            throw new BusinessException("地址解析失败：" + response.getOrDefault("message", "未知错误"));
        }
        @SuppressWarnings("unchecked")
        Map<String, Object> result = (Map<String, Object>) response.get("result");
        @SuppressWarnings("unchecked")
        Map<String, Object> location = (Map<String, Object>) result.get("location");
        BigDecimal lng = BigDecimal.valueOf(((Number) location.get("lng")).doubleValue());
        BigDecimal lat = BigDecimal.valueOf(((Number) location.get("lat")).doubleValue());

        return Map.of(
                "address", cleanAddress,
                "latitude", lat,
                "longitude", lng,
                "confidence", result.getOrDefault("confidence", 0),
                "level", result.getOrDefault("level", "")
        );
    }

    public Map<String, Object> reverseGeocode(double lat, double lng) {
        if (config.getMapAk() == null || config.getMapAk().isBlank()) {
            throw new BusinessException("未配置百度地图AK，请设置环境变量 BAIDU_MAP_AK 后重试");
        }

        URI uri = UriComponentsBuilder
                .fromHttpUrl("https://api.map.baidu.com/reverse_geocoding/v3/")
                .queryParam("location", lat + "," + lng)
                .queryParam("coordtype", "wgs84ll")
                .queryParam("extensions_poi", "1")
                .queryParam("output", "json")
                .queryParam("ak", config.getMapAk())
                .build(true)
                .toUri();

        Map<String, Object> response = getJson(uri);
        if (response == null) {
            throw new BusinessException("百度地图服务无响应");
        }
        Number status = (Number) response.get("status");
        if (status == null || status.intValue() != 0) {
            throw new BusinessException("逆地理编码失败：" + response.getOrDefault("message", "未知错误"));
        }

        @SuppressWarnings("unchecked")
        Map<String, Object> result = (Map<String, Object>) response.get("result");
        @SuppressWarnings("unchecked")
        Map<String, Object> component = (Map<String, Object>) result.getOrDefault("addressComponent", Map.of());

        Map<String, Object> data = new LinkedHashMap<>();
        data.put("latitude", lat);
        data.put("longitude", lng);
        data.put("formattedAddress", result.getOrDefault("formatted_address", ""));
        data.put("business", result.getOrDefault("business", ""));
        data.put("semanticDescription", result.getOrDefault("sematic_description", ""));
        data.put("province", component.getOrDefault("province", ""));
        data.put("city", component.getOrDefault("city", ""));
        data.put("district", component.getOrDefault("district", ""));
        data.put("town", component.getOrDefault("town", ""));
        data.put("street", component.getOrDefault("street", ""));
        data.put("streetNumber", component.getOrDefault("street_number", ""));
        data.put("adcode", component.getOrDefault("adcode", ""));
        data.put("country", component.getOrDefault("country", ""));
        data.put("countryCode", component.getOrDefault("country_code", ""));
        data.put("pois", summarizePois(result.get("pois")));
        return data;
    }

    private List<Map<String, Object>> summarizePois(Object poisObj) {
        if (!(poisObj instanceof List<?> pois)) return List.of();
        return pois.stream()
                .filter(Map.class::isInstance)
                .limit(5)
                .map(item -> {
                    @SuppressWarnings("unchecked")
                    Map<String, Object> poi = (Map<String, Object>) item;
                    Map<String, Object> data = new LinkedHashMap<>();
                    data.put("name", poi.getOrDefault("name", ""));
                    data.put("address", poi.getOrDefault("addr", ""));
                    data.put("distance", poi.getOrDefault("distance", ""));
                    data.put("type", poi.getOrDefault("poiType", ""));
                    return data;
                })
                .toList();
    }

    private Map<String, Object> getJson(URI uri) {
        try {
            String body = restTemplate.getForObject(uri, String.class);
            if (body == null || body.isBlank()) {
                throw new BusinessException("百度地图服务无响应");
            }
            return objectMapper.readValue(body, new TypeReference<>() {});
        } catch (BusinessException e) {
            throw e;
        } catch (Exception e) {
            throw new BusinessException("百度地图响应解析失败: " + e.getMessage());
        }
    }
}
