-- =============================================
-- AI思政打卡APP — SQL Server 数据库初始化脚本
-- 数据库: ai_sizheng
-- 版本: V1.0
-- 日期: 2026-06-26
-- =============================================

-- 注意：先在sqlcmd中执行 CREATE DATABASE ai_sizheng 然后 USE ai_sizheng

-- =============================================
-- 1. 用户表
-- =============================================
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='sys_user' AND xtype='U')
CREATE TABLE sys_user (
    id              BIGINT IDENTITY(1,1) PRIMARY KEY,
    student_id      NVARCHAR(20)  NOT NULL,
    real_name       NVARCHAR(50)  NOT NULL,
    password_hash   NVARCHAR(128) NOT NULL,
    role            NVARCHAR(20)  NOT NULL,          -- STUDENT / INSTRUCTOR / ADMIN
    class_id        BIGINT        NULL,
    phone           NVARCHAR(20)  NULL,
    face_registered BIT           DEFAULT 0,
    face_group_id   NVARCHAR(50)  NULL,
    status          NVARCHAR(10)  DEFAULT 'ACTIVE',  -- ACTIVE / SUSPENDED / GRADUATED
    created_at      DATETIME2     DEFAULT GETDATE(),
    updated_at      DATETIME2     DEFAULT GETDATE(),
    CONSTRAINT uq_student_id UNIQUE (student_id)
);
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name='idx_user_class')
    CREATE INDEX idx_user_class ON sys_user(class_id);
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name='idx_user_role_status')
    CREATE INDEX idx_user_role_status ON sys_user(role, status);
GO

-- =============================================
-- 2. 打卡点表
-- =============================================
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='checkin_site' AND xtype='U')
CREATE TABLE checkin_site (
    id              BIGINT IDENTITY(1,1) PRIMARY KEY,
    site_name       NVARCHAR(100) NOT NULL,
    site_type       NVARCHAR(20)  NOT NULL,          -- DORM / CLASSROOM / INTERNSHIP
    latitude        DECIMAL(10,7) NOT NULL,
    longitude       DECIMAL(10,7) NOT NULL,
    radius_meters   INT           DEFAULT 300,
    detail_address  NVARCHAR(255) NULL,
    status          NVARCHAR(10)  DEFAULT 'ACTIVE',
    created_at      DATETIME2     DEFAULT GETDATE()
);
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name='idx_site_type_status')
    CREATE INDEX idx_site_type_status ON checkin_site(site_type, status);
GO

-- =============================================
-- 2.1 课堂场次表
-- =============================================
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='class_session' AND xtype='U')
CREATE TABLE class_session (
    id              BIGINT IDENTITY(1,1) PRIMARY KEY,
    course_name     NVARCHAR(100) NOT NULL,
    teacher_name    NVARCHAR(50)  NOT NULL,
    class_id        BIGINT        NULL,
    site_id         BIGINT        NOT NULL,
    sign_mode       NVARCHAR(20)  DEFAULT 'LOCATION',
    start_time      DATETIME2     NOT NULL,
    end_time        DATETIME2     NOT NULL,
    sign_start_time DATETIME2     NOT NULL,
    sign_end_time   DATETIME2     NOT NULL,
    status          NVARCHAR(20)  DEFAULT 'ACTIVE',
    created_at      DATETIME2     DEFAULT GETDATE(),
    CONSTRAINT fk_class_session_site FOREIGN KEY (site_id) REFERENCES checkin_site(id)
);
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name='idx_class_session_time')
    CREATE INDEX idx_class_session_time ON class_session(class_id, sign_start_time, sign_end_time);
GO

IF EXISTS (SELECT * FROM sysobjects WHERE name='class_session' AND xtype='U')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE Name = N'sign_mode' AND Object_ID = Object_ID(N'class_session'))
    ALTER TABLE class_session ADD sign_mode NVARCHAR(20) NULL DEFAULT 'LOCATION';
GO

-- =============================================
-- 3. 打卡记录表
-- =============================================
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='checkin_record' AND xtype='U')
CREATE TABLE checkin_record (
    id              BIGINT IDENTITY(1,1) PRIMARY KEY,
    user_id         BIGINT        NOT NULL,
    site_id         BIGINT        NOT NULL,
    session_id      BIGINT        NULL,
    checkin_type    NVARCHAR(20)  NOT NULL,          -- DORM / CLASS / INTERNSHIP
    checkin_time    DATETIME2     NOT NULL,
    latitude        DECIMAL(10,7) NULL,
    longitude       DECIMAL(10,7) NULL,
    face_score      DECIMAL(5,2)  NULL,
    face_passed     BIT           NULL,
    location_passed BIT           NULL,
    liveness_passed BIT           NULL,
    status          NVARCHAR(20)  DEFAULT 'SUCCESS', -- SUCCESS / FAILED / APPEALED
    device_info     NVARCHAR(255) NULL,
    ip_address      NVARCHAR(45)  NULL,
    fail_reason     NVARCHAR(100) NULL,
    appeal_reason   NVARCHAR(MAX) NULL,
    appeal_status   NVARCHAR(20)  NULL,              -- PENDING / APPROVED / REJECTED
    appeal_review_comment NVARCHAR(MAX) NULL,
    appealed_at     DATETIME2     NULL,
    appeal_reviewed_at DATETIME2  NULL,
    created_at      DATETIME2     DEFAULT GETDATE(),
    CONSTRAINT fk_checkin_user FOREIGN KEY (user_id) REFERENCES sys_user(id),
    CONSTRAINT fk_checkin_site FOREIGN KEY (site_id) REFERENCES checkin_site(id),
    CONSTRAINT fk_checkin_session FOREIGN KEY (session_id) REFERENCES class_session(id)
);
GO

IF EXISTS (SELECT * FROM sysobjects WHERE name='checkin_record' AND xtype='U')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE Name = N'session_id' AND Object_ID = Object_ID(N'checkin_record'))
    ALTER TABLE checkin_record ADD session_id BIGINT NULL;
GO

IF EXISTS (SELECT * FROM sysobjects WHERE name='checkin_record' AND xtype='U')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE Name = N'appeal_reason' AND Object_ID = Object_ID(N'checkin_record'))
    ALTER TABLE checkin_record ADD appeal_reason NVARCHAR(MAX) NULL;
IF EXISTS (SELECT * FROM sysobjects WHERE name='checkin_record' AND xtype='U')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE Name = N'appeal_status' AND Object_ID = Object_ID(N'checkin_record'))
    ALTER TABLE checkin_record ADD appeal_status NVARCHAR(20) NULL;
IF EXISTS (SELECT * FROM sysobjects WHERE name='checkin_record' AND xtype='U')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE Name = N'appeal_review_comment' AND Object_ID = Object_ID(N'checkin_record'))
    ALTER TABLE checkin_record ADD appeal_review_comment NVARCHAR(MAX) NULL;
IF EXISTS (SELECT * FROM sysobjects WHERE name='checkin_record' AND xtype='U')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE Name = N'appealed_at' AND Object_ID = Object_ID(N'checkin_record'))
    ALTER TABLE checkin_record ADD appealed_at DATETIME2 NULL;
IF EXISTS (SELECT * FROM sysobjects WHERE name='checkin_record' AND xtype='U')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE Name = N'appeal_reviewed_at' AND Object_ID = Object_ID(N'checkin_record'))
    ALTER TABLE checkin_record ADD appeal_reviewed_at DATETIME2 NULL;
GO

IF EXISTS (SELECT * FROM sysobjects WHERE name='checkin_record' AND xtype='U')
AND NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'fk_checkin_session')
    ALTER TABLE checkin_record ADD CONSTRAINT fk_checkin_session FOREIGN KEY (session_id) REFERENCES class_session(id);
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name='idx_ck_user_time')
    CREATE INDEX idx_ck_user_time ON checkin_record(user_id, checkin_time);
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name='idx_ck_site_time')
    CREATE INDEX idx_ck_site_time ON checkin_record(site_id, checkin_time);
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name='idx_ck_type_date')
    CREATE INDEX idx_ck_type_date ON checkin_record(checkin_type, checkin_time);
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name='idx_ck_status')
    CREATE INDEX idx_ck_status ON checkin_record(status);
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name='idx_ck_session')
    CREATE INDEX idx_ck_session ON checkin_record(session_id, user_id);
GO

-- =============================================
-- 4. 实习日志表
-- =============================================
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='intern_log' AND xtype='U')
CREATE TABLE intern_log (
    id              BIGINT IDENTITY(1,1) PRIMARY KEY,
    user_id         BIGINT        NOT NULL,
    company_name    NVARCHAR(100) NOT NULL,
    work_date       DATE          NOT NULL,
    content         NVARCHAR(MAX) NOT NULL,
    mentor_review   NVARCHAR(MAX) NULL,
    mentor_id       BIGINT        NULL,
    created_at      DATETIME2     DEFAULT GETDATE(),
    CONSTRAINT uq_user_date UNIQUE (user_id, work_date),
    CONSTRAINT fk_internlog_user FOREIGN KEY (user_id) REFERENCES sys_user(id)
);
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name='idx_intern_company')
    CREATE INDEX idx_intern_company ON intern_log(company_name);
GO

-- =============================================
-- 5. 请假申请表
-- =============================================
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='leave_request' AND xtype='U')
CREATE TABLE leave_request (
    id              BIGINT IDENTITY(1,1) PRIMARY KEY,
    user_id         BIGINT        NOT NULL,
    leave_type      NVARCHAR(20)  NOT NULL,          -- SICK / PERSONAL / ACADEMIC
    start_time      DATETIME2     NOT NULL,
    end_time        DATETIME2     NOT NULL,
    reason          NVARCHAR(MAX) NOT NULL,
    attachment_url  NVARCHAR(255) NULL,
    status          NVARCHAR(20)  DEFAULT 'PENDING', -- PENDING / APPROVED / REJECTED
    reviewer_id     BIGINT        NULL,
    review_comment  NVARCHAR(MAX) NULL,
    reviewed_at     DATETIME2     NULL,
    created_at      DATETIME2     DEFAULT GETDATE(),
    CONSTRAINT fk_leave_user FOREIGN KEY (user_id) REFERENCES sys_user(id)
);
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name='idx_leave_user_status')
    CREATE INDEX idx_leave_user_status ON leave_request(user_id, status);
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name='idx_leave_reviewer')
    CREATE INDEX idx_leave_reviewer ON leave_request(reviewer_id, status);
GO

-- =============================================
-- 6. 通知消息表
-- =============================================
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='notification' AND xtype='U')
CREATE TABLE notification (
    id              BIGINT IDENTITY(1,1) PRIMARY KEY,
    receiver_id     BIGINT        NOT NULL,
    sender_id       BIGINT        NULL,
    notify_type     NVARCHAR(30)  NOT NULL,          -- REMINDER / WARNING / INFO / APPROVAL
    title           NVARCHAR(100) NOT NULL,
    content         NVARCHAR(MAX) NOT NULL,
    related_type    NVARCHAR(20)  NULL,              -- DORM / CLASS / INTERNSHIP
    related_id      BIGINT        NULL,
    is_read         BIT           DEFAULT 0,
    read_at         DATETIME2     NULL,
    created_at      DATETIME2     DEFAULT GETDATE()
);
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name='idx_notify_receiver')
    CREATE INDEX idx_notify_receiver ON notification(receiver_id, is_read, created_at);
GO

-- =============================================
-- 7. 操作审计表
-- =============================================
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='audit_log' AND xtype='U')
CREATE TABLE audit_log (
    id              BIGINT IDENTITY(1,1) PRIMARY KEY,
    user_id         BIGINT        NULL,
    action          NVARCHAR(50)  NOT NULL,
    resource        NVARCHAR(50)  NOT NULL,
    resource_id     BIGINT        NULL,
    detail          NVARCHAR(MAX) NULL,              -- JSON (SQL Server支持ISJSON校验)
    ip_address      NVARCHAR(45)  NULL,
    user_agent      NVARCHAR(255) NULL,
    created_at      DATETIME2     DEFAULT GETDATE()
);
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name='idx_audit_user_action')
    CREATE INDEX idx_audit_user_action ON audit_log(user_id, action, created_at);
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name='idx_audit_created')
    CREATE INDEX idx_audit_created ON audit_log(created_at);
GO

-- =============================================
-- 8. 初始测试数据（可选）
-- =============================================
-- 插入默认管理员 (密码: admin123 -> BCrypt hash)
-- INSERT INTO sys_user (student_id, real_name, password_hash, role, status)
-- VALUES ('admin', N'系统管理员', '$2a$12$...', 'ADMIN', 'ACTIVE');
-- GO

PRINT '====== 数据库初始化完成 ======';
PRINT '已创建/更新8张表: sys_user, checkin_site, class_session, checkin_record, intern_log, leave_request, notification, audit_log';
GO
