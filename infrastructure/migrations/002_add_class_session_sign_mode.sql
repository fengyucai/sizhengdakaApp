SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF EXISTS (SELECT * FROM sysobjects WHERE name='class_session' AND xtype='U')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE Name = N'sign_mode' AND Object_ID = Object_ID(N'class_session'))
    ALTER TABLE class_session ADD sign_mode NVARCHAR(20) NULL DEFAULT 'LOCATION';
GO

IF EXISTS (SELECT * FROM sysobjects WHERE name='class_session' AND xtype='U')
    UPDATE class_session SET sign_mode = 'LOCATION' WHERE sign_mode IS NULL;
GO
