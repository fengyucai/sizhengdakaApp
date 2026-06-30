package com.nhu.aisizheng;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.nhu.aisizheng.model.CheckinRecord;
import com.nhu.aisizheng.model.CheckinSite;
import com.nhu.aisizheng.model.LeaveRequest;
import com.nhu.aisizheng.model.User;
import com.nhu.aisizheng.repository.AuditLogRepository;
import com.nhu.aisizheng.repository.CheckinRecordRepository;
import com.nhu.aisizheng.repository.CheckinSiteRepository;
import com.nhu.aisizheng.repository.ClassSessionRepository;
import com.nhu.aisizheng.repository.InternLogRepository;
import com.nhu.aisizheng.repository.LeaveRequestRepository;
import com.nhu.aisizheng.repository.NotificationRepository;
import com.nhu.aisizheng.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class BackendApiIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private CheckinSiteRepository siteRepository;

    @Autowired
    private ClassSessionRepository classSessionRepository;

    @Autowired
    private CheckinRecordRepository checkinRecordRepository;

    @Autowired
    private LeaveRequestRepository leaveRequestRepository;

    @Autowired
    private NotificationRepository notificationRepository;

    @Autowired
    private AuditLogRepository auditLogRepository;

    @Autowired
    private InternLogRepository internLogRepository;

    private User student;
    private User teacher;
    private CheckinSite classSite;

    @BeforeEach
    void setUp() {
        auditLogRepository.deleteAll();
        notificationRepository.deleteAll();
        checkinRecordRepository.deleteAll();
        classSessionRepository.deleteAll();
        internLogRepository.deleteAll();
        leaveRequestRepository.deleteAll();
        siteRepository.deleteAll();
        userRepository.deleteAll();

        student = userRepository.save(User.builder()
                .studentId("20260001")
                .realName("学生测试")
                .passwordHash(passwordEncoder.encode("123456"))
                .role("STUDENT")
                .classId(1L)
                .faceRegistered(true)
                .status("ACTIVE")
                .createdAt(LocalDateTime.now())
                .build());
        teacher = userRepository.save(User.builder()
                .studentId("T2026001")
                .realName("辅导员测试")
                .passwordHash(passwordEncoder.encode("123456"))
                .role("INSTRUCTOR")
                .classId(1L)
                .faceRegistered(false)
                .status("ACTIVE")
                .createdAt(LocalDateTime.now())
                .build());
        classSite = siteRepository.save(CheckinSite.builder()
                .siteName("测试课堂点")
                .siteType("CLASSROOM")
                .latitude(new BigDecimal("26.8891000"))
                .longitude(new BigDecimal("112.5942000"))
                .radiusMeters(300)
                .detailAddress("湖南省衡阳市测试课堂")
                .status("ACTIVE")
                .createdAt(LocalDateTime.now())
                .build());
    }

    @Test
    void loginReturnsRoleAndToken() throws Exception {
        mockMvc.perform(post("/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("studentId", student.getStudentId(), "password", "123456"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.data.role").value("STUDENT"))
                .andExpect(jsonPath("$.data.accessToken").isNotEmpty());
    }

    @Test
    void teacherCreatesManualClassSessionAndStudentCanCheckIn() throws Exception {
        String teacherToken = login(teacher.getStudentId(), "123456");
        String studentToken = login(student.getStudentId(), "123456");

        Long sessionId = postAndReadData("/manage/class/mobile-session", teacherToken, Map.of(
                "mode", "MANUAL",
                "courseName", "软件工程",
                "teacherName", "辅导员测试",
                "classId", 1,
                "siteId", classSite.getId(),
                "durationMinutes", 30
        )).get("id").asLong();

        mockMvc.perform(get("/checkin/class/sessions/active")
                        .header("Authorization", bearer(studentToken)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.data[0].id").value(sessionId))
                .andExpect(jsonPath("$.data[0].signMode").value("MANUAL"));

        mockMvc.perform(post("/checkin/class")
                        .header("Authorization", bearer(studentToken))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of(
                                "sessionId", sessionId,
                                "siteId", classSite.getId(),
                                "latitude", classSite.getLatitude(),
                                "longitude", classSite.getLongitude(),
                                "deviceInfo", "mockmvc-test"
                        ))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.data.status").value("SUCCESS"));

        assertThat(checkinRecordRepository.findSuccessfulClassSessionCheckin(student.getId(), sessionId)).isPresent();
        assertThat(notificationRepository.findByReceiverIdOrderByCreatedAtDesc(student.getId()))
                .anyMatch(notification -> "CLASS_SESSION".equals(notification.getRelatedType()));
        assertThat(auditLogRepository.findAll())
                .anyMatch(log -> "CLASS_SESSION_CREATE".equals(log.getAction())
                        && "CLASS_SESSION".equals(log.getResource())
                        && sessionId.equals(log.getResourceId()));
    }

    @Test
    void teacherApproveLeaveWritesAuditLogAndNotification() throws Exception {
        String teacherToken = login(teacher.getStudentId(), "123456");
        LeaveRequest leave = leaveRequestRepository.save(LeaveRequest.builder()
                .userId(student.getId())
                .leaveType("SICK")
                .startTime(LocalDateTime.now().plusHours(1))
                .endTime(LocalDateTime.now().plusHours(5))
                .reason("测试请假")
                .status("PENDING")
                .createdAt(LocalDateTime.now())
                .build());

        mockMvc.perform(post("/manage/leave/{id}/approve", leave.getId())
                        .header("Authorization", bearer(teacherToken))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("comment", "同意"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200));

        LeaveRequest updated = leaveRequestRepository.findById(leave.getId()).orElseThrow();
        assertThat(updated.getStatus()).isEqualTo("APPROVED");
        assertThat(updated.getReviewerId()).isEqualTo(teacher.getId());
        assertThat(notificationRepository.findByReceiverIdOrderByCreatedAtDesc(student.getId()))
                .anyMatch(notification -> "LEAVE".equals(notification.getRelatedType())
                        && leave.getId().equals(notification.getRelatedId()));
        assertThat(auditLogRepository.findAll())
                .anyMatch(log -> "LEAVE_APPROVED".equals(log.getAction())
                        && "LEAVE_REQUEST".equals(log.getResource())
                        && leave.getId().equals(log.getResourceId()));
    }

    @Test
    void teacherReportInsightsReturnsClassSummaryAndRiskLists() throws Exception {
        String teacherToken = login(teacher.getStudentId(), "123456");
        leaveRequestRepository.save(LeaveRequest.builder()
                .userId(student.getId())
                .leaveType("PERSONAL")
                .startTime(LocalDateTime.now().minusHours(1))
                .endTime(LocalDateTime.now().plusHours(1))
                .reason("测试冲突请假")
                .status("APPROVED")
                .createdAt(LocalDateTime.now().minusHours(2))
                .build());

        mockMvc.perform(get("/manage/report/insights")
                        .queryParam("days", "7")
                        .header("Authorization", bearer(teacherToken)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.data.summary.studentTotal").value(1))
                .andExpect(jsonPath("$.data.classSummary[0].classId").value(1))
                .andExpect(jsonPath("$.data.abnormalStudents").isArray())
                .andExpect(jsonPath("$.data.leaveConflicts").isArray());
    }

    @Test
    void teacherCanManageStudentAccountAndReadAbnormalRecords() throws Exception {
        String teacherToken = login(teacher.getStudentId(), "123456");
        checkinRecordRepository.save(CheckinRecord.builder()
                .userId(student.getId())
                .siteId(classSite.getId())
                .checkinType("CLASS")
                .checkinTime(LocalDateTime.now().minusHours(1))
                .latitude(classSite.getLatitude())
                .longitude(classSite.getLongitude())
                .locationPassed(false)
                .facePassed(false)
                .status("FAILED")
                .failReason("distance exceeded")
                .createdAt(LocalDateTime.now().minusHours(1))
                .build());

        mockMvc.perform(get("/manage/students")
                        .header("Authorization", bearer(teacherToken)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.data[0].recentAbnormalCount").value(1));

        mockMvc.perform(post("/manage/students/{id}/status", student.getId())
                        .header("Authorization", bearer(teacherToken))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("status", "SUSPENDED"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.data.status").value("SUSPENDED"));

        mockMvc.perform(get("/manage/students")
                        .header("Authorization", bearer(teacherToken)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data[0].status").value("SUSPENDED"));

        mockMvc.perform(post("/manage/students/{id}/reset-password", student.getId())
                        .header("Authorization", bearer(teacherToken))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("newPassword", "654321"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200));

        assertThat(passwordEncoder.matches("654321",
                userRepository.findById(student.getId()).orElseThrow().getPasswordHash())).isTrue();
        mockMvc.perform(get("/manage/students/{id}/abnormal-records", student.getId())
                        .header("Authorization", bearer(teacherToken)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.data[0].status").value("FAILED"));
        assertThat(auditLogRepository.findAll())
                .anyMatch(log -> "STUDENT_PASSWORD_RESET".equals(log.getAction()))
                .anyMatch(log -> "STUDENT_STATUS_UPDATE".equals(log.getAction()));
    }

    private String login(String studentId, String password) throws Exception {
        JsonNode data = postAndReadData("/auth/login", null, Map.of(
                "studentId", studentId,
                "password", password
        ));
        return data.get("accessToken").asText();
    }

    private JsonNode postAndReadData(String path, String token, Object body) throws Exception {
        var request = post(path)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json(body));
        if (token != null) {
            request.header("Authorization", bearer(token));
        }
        String response = mockMvc.perform(request)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andReturn()
                .getResponse()
                .getContentAsString();
        return objectMapper.readTree(response).get("data");
    }

    private String json(Object value) throws Exception {
        return objectMapper.writeValueAsString(value);
    }

    private String bearer(String token) {
        return "Bearer " + token;
    }
}
