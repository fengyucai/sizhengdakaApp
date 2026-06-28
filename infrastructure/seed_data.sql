-- =============================================
-- AI思政打卡APP — 测试种子数据
-- 密码统一: 123456
-- BCrypt: $2b$12$h5G0c.N7ehyjF8MzNBjzo.nIrvCleP.zGjzu7OeeKmhByNNpo4Qiq
-- =============================================
USE ai_sizheng;
GO

-- 清理旧数据
DELETE FROM checkin_record;
DELETE FROM notification;
DELETE FROM leave_request;
DELETE FROM intern_log;
DELETE FROM audit_log;
DELETE FROM class_session;
DELETE FROM checkin_site;
DELETE FROM sys_user;
GO

-- =========================================
-- 1. 用户数据
-- =========================================
INSERT INTO sys_user (student_id, real_name, password_hash, role, class_id, phone, face_registered, status) VALUES
-- 管理员
('admin', N'张管理员', '$2b$12$h5G0c.N7ehyjF8MzNBjzo.nIrvCleP.zGjzu7OeeKmhByNNpo4Qiq', 'ADMIN', NULL, '13800000001', 1, 'ACTIVE'),
-- 辅导员
('T2024001', N'李辅导员', '$2b$12$h5G0c.N7ehyjF8MzNBjzo.nIrvCleP.zGjzu7OeeKmhByNNpo4Qiq', 'INSTRUCTOR', 1, '13800000002', 0, 'ACTIVE'),
('T2024002', N'王辅导员', '$2b$12$h5G0c.N7ehyjF8MzNBjzo.nIrvCleP.zGjzu7OeeKmhByNNpo4Qiq', 'INSTRUCTOR', 2, '13800000003', 0, 'ACTIVE'),
-- 软件2101班 (大一) 学生
('20240101', N'张小明', '$2b$12$h5G0c.N7ehyjF8MzNBjzo.nIrvCleP.zGjzu7OeeKmhByNNpo4Qiq', 'STUDENT', 1, '13900000101', 1, 'ACTIVE'),
('20240102', N'李小红', '$2b$12$h5G0c.N7ehyjF8MzNBjzo.nIrvCleP.zGjzu7OeeKmhByNNpo4Qiq', 'STUDENT', 1, '13900000102', 1, 'ACTIVE'),
('20240103', N'王大伟', '$2b$12$h5G0c.N7ehyjF8MzNBjzo.nIrvCleP.zGjzu7OeeKmhByNNpo4Qiq', 'STUDENT', 1, '13900000103', 1, 'ACTIVE'),
('20240104', N'赵小芳', '$2b$12$h5G0c.N7ehyjF8MzNBjzo.nIrvCleP.zGjzu7OeeKmhByNNpo4Qiq', 'STUDENT', 1, '13900000104', 1, 'ACTIVE'),
-- 计科2102班 (大二) 学生
('20240105', N'钱同学', '$2b$12$h5G0c.N7ehyjF8MzNBjzo.nIrvCleP.zGjzu7OeeKmhByNNpo4Qiq', 'STUDENT', 2, '13900000201', 1, 'ACTIVE'),
('20240106', N'孙同学', '$2b$12$h5G0c.N7ehyjF8MzNBjzo.nIrvCleP.zGjzu7OeeKmhByNNpo4Qiq', 'STUDENT', 2, '13900000202', 1, 'ACTIVE'),
-- 实习生
('20240107', N'刘实习生', '$2b$12$h5G0c.N7ehyjF8MzNBjzo.nIrvCleP.zGjzu7OeeKmhByNNpo4Qiq', 'STUDENT', 3, '13900000301', 1, 'ACTIVE'),
('20240108', N'陈实习生', '$2b$12$h5G0c.N7ehyjF8MzNBjzo.nIrvCleP.zGjzu7OeeKmhByNNpo4Qiq', 'STUDENT', 3, '13900000302', 1, 'ACTIVE');
GO

-- =========================================
-- 2. 打卡点数据
-- =========================================
INSERT INTO checkin_site (site_name, site_type, latitude, longitude, radius_meters, detail_address, status) VALUES
-- 查寝打卡点
(N'一栋宿舍楼', 'DORM', 26.8943, 112.5745, 300, N'南华大学红湘校区一栋', 'ACTIVE'),
(N'二栋宿舍楼', 'DORM', 26.8938, 112.5750, 300, N'南华大学红湘校区二栋', 'ACTIVE'),
(N'三栋宿舍楼', 'DORM', 26.8948, 112.5738, 300, N'南华大学红湘校区三栋', 'ACTIVE'),
-- 上课打卡点
(N'计算机楼A201', 'CLASSROOM', 26.8935, 112.5760, 200, N'南华大学计算机学院A201', 'ACTIVE'),
(N'计算机楼A301', 'CLASSROOM', 26.8935, 112.5760, 200, N'南华大学计算机学院A301', 'ACTIVE'),
(N'一教101', 'CLASSROOM', 26.8928, 112.5775, 200, N'南华大学一教101', 'ACTIVE'),
-- 实习打卡点
(N'湘南软件园A公司', 'INTERNSHIP', 26.8500, 113.0200, 500, N'湘南软件园A栋3层', 'ACTIVE'),
(N'湘南软件园B公司', 'INTERNSHIP', 26.8505, 113.0210, 500, N'湘南软件园B栋5层', 'ACTIVE'),
(N'某科技公司', 'INTERNSHIP', 26.8800, 112.6100, 500, N'长沙市岳麓区某科技园', 'ACTIVE');
GO

-- =========================================
-- 2.1 课堂场次数据
-- =========================================
INSERT INTO class_session (course_name, teacher_name, class_id, site_id, start_time, end_time, sign_start_time, sign_end_time, status)
VALUES
(N'数据结构', N'陈教授', 1, 4,
 DATEADD(HOUR, 8, CAST(CAST(GETDATE() AS DATE) AS DATETIME2)),
 DATEADD(MINUTE, 40, DATEADD(HOUR, 9, CAST(CAST(GETDATE() AS DATE) AS DATETIME2))),
 DATEADD(MINUTE, -5, DATEADD(HOUR, 8, CAST(CAST(GETDATE() AS DATE) AS DATETIME2))),
 DATEADD(MINUTE, 10, DATEADD(HOUR, 8, CAST(CAST(GETDATE() AS DATE) AS DATETIME2))),
 'ACTIVE'),
(N'操作系统', N'刘教授', 1, 5,
 DATEADD(HOUR, 10, CAST(CAST(GETDATE() AS DATE) AS DATETIME2)),
 DATEADD(MINUTE, 40, DATEADD(HOUR, 11, CAST(CAST(GETDATE() AS DATE) AS DATETIME2))),
 DATEADD(MINUTE, -5, DATEADD(HOUR, 10, CAST(CAST(GETDATE() AS DATE) AS DATETIME2))),
 DATEADD(MINUTE, 10, DATEADD(HOUR, 10, CAST(CAST(GETDATE() AS DATE) AS DATETIME2))),
 'ACTIVE');
GO

-- =========================================
-- 3. 测试打卡记录 (模拟最近数据)
-- =========================================
DECLARE @yesterday DATETIME2 = DATEADD(DAY, -1, GETDATE());
DECLARE @today DATETIME2 = GETDATE();

-- 昨天的查寝记录 (全员成功)
INSERT INTO checkin_record (user_id, site_id, checkin_type, checkin_time, latitude, longitude, face_score, face_passed, location_passed, liveness_passed, status, device_info, ip_address)
SELECT
    u.id, 1, 'DORM',
    DATEADD(MINUTE, ABS(CHECKSUM(NEWID())) % 120, DATEADD(HOUR, 21, @yesterday)),
    26.8943, 112.5745,
    90 + (ABS(CHECKSUM(NEWID())) % 10),
    1, 1, 1, 'SUCCESS',
    'Xiaomi 14/Android 14', '10.0.0.1'
FROM sys_user u WHERE u.role = 'STUDENT' AND u.status = 'ACTIVE';

-- 今天的查寝记录 (部分已完成)
INSERT INTO checkin_record (user_id, site_id, checkin_type, checkin_time, latitude, longitude, face_score, face_passed, location_passed, liveness_passed, status, device_info, ip_address)
SELECT TOP 5
    u.id, 1, 'DORM',
    DATEADD(MINUTE, ABS(CHECKSUM(NEWID())) % 60, DATEADD(HOUR, 21, @today)),
    26.8943, 112.5745,
    90 + (ABS(CHECKSUM(NEWID())) % 10),
    1, 1, 1, 'SUCCESS',
    'iPhone 15/iOS 18', '10.0.0.2'
FROM sys_user u WHERE u.role = 'STUDENT' AND u.status = 'ACTIVE'
ORDER BY NEWID();

-- 异常打卡示例 (未打卡/失败)
INSERT INTO checkin_record (user_id, site_id, checkin_type, checkin_time, latitude, longitude, face_score, face_passed, location_passed, liveness_passed, status, fail_reason, device_info, ip_address)
VALUES
(5, 1, 'DORM', DATEADD(HOUR, 22, @today), 26.9000, 112.5800, 45.0, 0, 1, 0, 'FAILED', N'人脸验证不通过', 'OPPO Find/Android 14', '10.0.0.3'),
(6, 1, 'DORM', DATEADD(HOUR, 21, @yesterday), 23.1200, 113.3600, 88.0, 1, 0, 1, 'FAILED', N'不在打卡范围内', 'Honor/Android 13', '10.0.0.4');

-- 上课打卡记录
INSERT INTO checkin_record (user_id, site_id, session_id, checkin_type, checkin_time, latitude, longitude, location_passed, status, device_info, ip_address)
SELECT TOP 6
    u.id, 4, 1, 'CLASS',
    DATEADD(MINUTE, ABS(CHECKSUM(NEWID())) % 10, DATEADD(HOUR, 8, @today)),
    26.8935, 112.5760,
    1, 'SUCCESS',
    'Samsung S24/Android 14', '10.0.0.5'
FROM sys_user u WHERE u.role = 'STUDENT' AND u.status = 'ACTIVE'
ORDER BY NEWID();

-- 实习打卡记录
INSERT INTO checkin_record (user_id, site_id, checkin_type, checkin_time, latitude, longitude, location_passed, status, device_info, ip_address)
VALUES
(9, 7, 'INTERNSHIP', DATEADD(HOUR, 9, @today), 26.8500, 113.0200, 1, 'SUCCESS', 'Vivo X100/Android 14', '10.0.1.1'),
(10, 8, 'INTERNSHIP', DATEADD(HOUR, 8, @today), 26.8505, 113.0210, 1, 'SUCCESS', 'Realme/Android 14', '10.0.1.2');
GO

-- =========================================
-- 4. 请假申请示例
-- =========================================
INSERT INTO leave_request (user_id, leave_type, start_time, end_time, reason, status, reviewer_id, review_comment, reviewed_at)
VALUES
(4, 'SICK', DATEADD(DAY, -1, GETDATE()), DATEADD(DAY, 1, GETDATE()), N'感冒就医，已开具校医院证明', 'APPROVED', 2, N'已核实，注意休息', GETDATE()),
(7, 'PERSONAL', DATEADD(DAY, 1, GETDATE()), DATEADD(DAY, 2, GETDATE()), N'家中急事需返家处理', 'PENDING', NULL, NULL, NULL);
GO

-- =========================================
-- 5. 通知消息示例
-- =========================================
INSERT INTO notification (receiver_id, sender_id, notify_type, title, content, related_type, related_id, is_read)
VALUES
(3, NULL, 'REMINDER', N'查寝提醒', N'请于23:00前完成查寝打卡', 'DORM', NULL, 0),
(5, NULL, 'WARNING', N'查寝异常', N'您的人脸验证未通过，请重新打卡', 'DORM', 8, 0),
(6, NULL, 'WARNING', N'打卡位置异常', N'您的打卡位置超出电子围栏范围', 'DORM', 9, 1);
GO

-- =========================================
-- 6. 实习日志示例
-- =========================================
INSERT INTO intern_log (user_id, company_name, work_date, content)
VALUES
(9, N'湘南软件园A公司', CAST(GETDATE() AS DATE), N'今日完成了用户管理模块的单元测试，编写了12个测试用例，覆盖了正常登录、密码错误、账号锁定三个场景。遇到了Mock数据库连接的问题，在导师指导下通过Mockito框架解决了依赖隔离。明天计划开始集成Redis缓存层的测试。'),
(10, N'湘南软件园B公司', CAST(GETDATE() AS DATE), N'参与产品需求评审会，整理了3个功能点的技术可行性分析报告。下午用Spring Boot搭建了文件上传微服务的原型，实现了大文件分片上传功能。遇到MinIO配置问题已查阅文档解决。明日计划联调前端上传接口。');
GO

-- =========================================
-- 汇总
-- =========================================
PRINT '====== 种子数据插入完毕 ======';
SELECT '用户' AS category, COUNT(*) AS cnt FROM sys_user
UNION ALL
SELECT '打卡点', COUNT(*) FROM checkin_site
UNION ALL
SELECT '打卡记录', COUNT(*) FROM checkin_record
UNION ALL
SELECT '课堂场次', COUNT(*) FROM class_session
UNION ALL
SELECT '请假申请', COUNT(*) FROM leave_request
UNION ALL
SELECT '通知消息', COUNT(*) FROM notification
UNION ALL
SELECT '实习日志', COUNT(*) FROM intern_log;
GO
