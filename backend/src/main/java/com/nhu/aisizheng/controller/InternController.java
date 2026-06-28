package com.nhu.aisizheng.controller;

import com.nhu.aisizheng.common.Result;
import com.nhu.aisizheng.model.InternLog;
import com.nhu.aisizheng.repository.InternLogRepository;
import com.nhu.aisizheng.utils.JwtUtils;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

/**
 * 学生端实习日志接口
 */
@RestController
@RequestMapping("/intern")
@RequiredArgsConstructor
public class InternController {

    private final InternLogRepository internLogRepository;
    private final JwtUtils jwtUtils;

    @GetMapping("/logs")
    public Result<List<Map<String, Object>>> myLogs(HttpServletRequest request) {
        Long userId = currentUserId(request);
        return Result.success(internLogRepository.findByUserIdOrderByWorkDateDesc(userId)
                .stream()
                .map(this::toMap)
                .toList());
    }

    private Map<String, Object> toMap(InternLog log) {
        return Map.of(
                "id", log.getId(),
                "workDate", log.getWorkDate() != null ? log.getWorkDate().toString() : "",
                "companyName", log.getCompanyName(),
                "content", log.getContent(),
                "mentorReview", log.getMentorReview() != null ? log.getMentorReview() : "",
                "reviewed", log.getMentorReview() != null && !log.getMentorReview().isBlank()
        );
    }

    private Long currentUserId(HttpServletRequest request) {
        String token = request.getHeader("Authorization").replace("Bearer ", "");
        return jwtUtils.getUserId(token);
    }
}
