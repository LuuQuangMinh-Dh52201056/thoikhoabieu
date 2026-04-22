IF DB_ID(N'thoikhoabieu') IS NULL
BEGIN
    CREATE DATABASE thoikhoabieu;
END;
GO

USE thoikhoabieu;
GO

IF OBJECT_ID(N'dbo.AppUsers', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.AppUsers (
        Id UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_AppUsers PRIMARY KEY DEFAULT NEWID(),
        Email NVARCHAR(256) NOT NULL,
        PasswordHash NVARCHAR(500) NOT NULL,
        DisplayName NVARCHAR(160) NOT NULL,
        Role NVARCHAR(20) NOT NULL CONSTRAINT DF_AppUsers_Role DEFAULT N'user',
        Active BIT NOT NULL CONSTRAINT DF_AppUsers_Active DEFAULT 1,
        Deleted BIT NOT NULL CONSTRAINT DF_AppUsers_Deleted DEFAULT 0,
        CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_AppUsers_CreatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy UNIQUEIDENTIFIER NULL,
        UpdatedAt DATETIME2 NULL,
        UpdatedBy UNIQUEIDENTIFIER NULL,
        DeletedAt DATETIME2 NULL,
        DeletedBy UNIQUEIDENTIFIER NULL,
        CONSTRAINT UQ_AppUsers_Email UNIQUE (Email)
    );
END;
GO

IF OBJECT_ID(N'dbo.Schedules', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Schedules (
        Id UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_Schedules PRIMARY KEY DEFAULT NEWID(),
        Date DATE NOT NULL,
        StartHour INT NOT NULL,
        EndHour INT NOT NULL,
        TeacherName NVARCHAR(160) NOT NULL,
        StudentName NVARCHAR(160) NOT NULL,
        Course NVARCHAR(30) NOT NULL,
        Content NVARCHAR(500) NOT NULL,
        Vehicle NVARCHAR(80) NULL,
        AssistantName NVARCHAR(160) NULL,
        Location NVARCHAR(240) NULL,
        Note NVARCHAR(1000) NULL,
        Category NVARCHAR(80) NOT NULL,
        CreatedBy UNIQUEIDENTIFIER NOT NULL,
        CreatedByEmail NVARCHAR(256) NOT NULL,
        CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_Schedules_CreatedAt DEFAULT SYSUTCDATETIME(),
        UpdatedAt DATETIME2 NULL,
        UpdatedBy UNIQUEIDENTIFIER NULL,
        CONSTRAINT CK_Schedules_Hours CHECK (StartHour >= 7 AND EndHour <= 18 AND EndHour > StartHour),
        CONSTRAINT FK_Schedules_AppUsers FOREIGN KEY (CreatedBy) REFERENCES dbo.AppUsers(Id)
    );
END;
GO
