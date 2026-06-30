SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='audit_log' AND xtype='U')
CREATE TABLE audit_log (
    id              BIGINT IDENTITY(1,1) PRIMARY KEY,
    user_id         BIGINT        NULL,
    action          NVARCHAR(50)  NOT NULL,
    resource        NVARCHAR(50)  NOT NULL,
    resource_id     BIGINT        NULL,
    detail          NVARCHAR(MAX) NULL,
    ip_address      NVARCHAR(45)  NULL,
    user_agent      NVARCHAR(255) NULL,
    created_at      DATETIME2     DEFAULT GETDATE()
);
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name='idx_audit_user_action')
    CREATE INDEX idx_audit_user_action ON audit_log(user_id, action, created_at);
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name='idx_audit_created')
    CREATE INDEX idx_audit_created ON audit_log(created_at);
GO
