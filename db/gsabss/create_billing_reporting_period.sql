USE GSABSS;

SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF OBJECT_ID(N'dbo.Billing_Reporting_Period', N'U') IS NULL
BEGIN
  CREATE TABLE dbo.Billing_Reporting_Period
  (
    singleton_id tinyint NOT NULL,
    FYEAR varchar(10) NOT NULL,
    APMON varchar(4) NOT NULL,
    SDATE date NOT NULL,
    EDATE date NOT NULL,
    CONSTRAINT PK_Billing_Reporting_Period PRIMARY KEY (singleton_id),
    CONSTRAINT CK_Billing_Reporting_Period_Singleton CHECK (singleton_id = 1),
    CONSTRAINT CK_Billing_Reporting_Period_Dates CHECK (SDATE <= EDATE)
  );
END;

GRANT SELECT, INSERT, UPDATE ON OBJECT::dbo.Billing_Reporting_Period TO [GSAETL];

COMMIT TRANSACTION;
