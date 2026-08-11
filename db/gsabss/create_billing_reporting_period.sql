USE GSABSS;

SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF OBJECT_ID(N'dbo.Billing_Reporting_Period', N'U') IS NULL
BEGIN
  CREATE TABLE dbo.Billing_Reporting_Period
  (
    billing_reporting_period_id uniqueidentifier NOT NULL
      CONSTRAINT DF_Billing_Reporting_Period_Id DEFAULT NEWSEQUENTIALID(),
    FYEAR varchar(10) NOT NULL,
    APMON varchar(4) NOT NULL,
    SDATE date NOT NULL,
    EDATE date NOT NULL,
    VERSION int NOT NULL
      CONSTRAINT DF_Billing_Reporting_Period_Version DEFAULT (1),
    ACTIVE bit NOT NULL
      CONSTRAINT DF_Billing_Reporting_Period_Active DEFAULT (0),
    CONSTRAINT PK_Billing_Reporting_Period
      PRIMARY KEY (billing_reporting_period_id),
    CONSTRAINT CK_Billing_Reporting_Period_Dates CHECK (SDATE <= EDATE),
    CONSTRAINT CK_Billing_Reporting_Period_Version CHECK (VERSION >= 1)
  );
END;

IF COL_LENGTH('dbo.Billing_Reporting_Period', 'billing_reporting_period_id') IS NULL
BEGIN
  ALTER TABLE dbo.Billing_Reporting_Period
    ADD billing_reporting_period_id uniqueidentifier NOT NULL
      CONSTRAINT DF_Billing_Reporting_Period_Id DEFAULT NEWSEQUENTIALID()
      WITH VALUES;
END;

IF COL_LENGTH('dbo.Billing_Reporting_Period', 'VERSION') IS NULL
BEGIN
  ALTER TABLE dbo.Billing_Reporting_Period
    ADD VERSION int NOT NULL
      CONSTRAINT DF_Billing_Reporting_Period_Version DEFAULT (1)
      WITH VALUES;
END;

IF COL_LENGTH('dbo.Billing_Reporting_Period', 'ACTIVE') IS NULL
BEGIN
  ALTER TABLE dbo.Billing_Reporting_Period
    ADD ACTIVE bit NOT NULL
      CONSTRAINT DF_Billing_Reporting_Period_Active DEFAULT (1)
      WITH VALUES;
END;

IF COL_LENGTH('dbo.Billing_Reporting_Period', 'singleton_id') IS NOT NULL
BEGIN
  IF OBJECT_ID(N'dbo.PK_Billing_Reporting_Period', N'PK') IS NOT NULL
    ALTER TABLE dbo.Billing_Reporting_Period
      DROP CONSTRAINT PK_Billing_Reporting_Period;

  IF OBJECT_ID(N'dbo.CK_Billing_Reporting_Period_Singleton', N'C') IS NOT NULL
    ALTER TABLE dbo.Billing_Reporting_Period
      DROP CONSTRAINT CK_Billing_Reporting_Period_Singleton;

  ALTER TABLE dbo.Billing_Reporting_Period DROP COLUMN singleton_id;
END;

IF OBJECT_ID(N'dbo.PK_Billing_Reporting_Period', N'PK') IS NULL
BEGIN
  ALTER TABLE dbo.Billing_Reporting_Period
    ADD CONSTRAINT PK_Billing_Reporting_Period
      PRIMARY KEY (billing_reporting_period_id);
END;

IF OBJECT_ID(N'dbo.CK_Billing_Reporting_Period_Version', N'C') IS NULL
BEGIN
  EXEC(N'
    ALTER TABLE dbo.Billing_Reporting_Period
      ADD CONSTRAINT CK_Billing_Reporting_Period_Version
        CHECK (VERSION >= 1);
  ');
END;

IF NOT EXISTS (
  SELECT 1 FROM sys.indexes
  WHERE name = N'UX_Billing_Reporting_Period_Period'
    AND object_id = OBJECT_ID(N'dbo.Billing_Reporting_Period')
)
BEGIN
  CREATE UNIQUE INDEX UX_Billing_Reporting_Period_Period
    ON dbo.Billing_Reporting_Period (FYEAR, APMON);
END;

IF NOT EXISTS (
  SELECT 1 FROM sys.indexes
  WHERE name = N'UX_Billing_Reporting_Period_Active'
    AND object_id = OBJECT_ID(N'dbo.Billing_Reporting_Period')
)
BEGIN
  EXEC(N'
    CREATE UNIQUE INDEX UX_Billing_Reporting_Period_Active
      ON dbo.Billing_Reporting_Period (ACTIVE)
      WHERE ACTIVE = 1;
  ');
END;

GRANT SELECT, INSERT, UPDATE ON OBJECT::dbo.Billing_Reporting_Period TO [GSAETL];

COMMIT TRANSACTION;
