USE GSABSS;

SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF OBJECT_ID(N'dbo.Billing_Email_Recipients', N'U') IS NULL
BEGIN
  CREATE TABLE dbo.Billing_Email_Recipients
  (
    id int IDENTITY(1, 1) NOT NULL,
    email_address varchar(254) NOT NULL,
    CONSTRAINT PK_Billing_Email_Recipients PRIMARY KEY (id),
    CONSTRAINT UQ_Billing_Email_Recipients_Email UNIQUE (email_address)
  );
END;

IF OBJECT_ID(N'dbo.Billing_Email_Subjects', N'U') IS NULL
BEGIN
  CREATE TABLE dbo.Billing_Email_Subjects
  (
    billing_type varchar(3) NOT NULL,
    subject_format varchar(500) NOT NULL,
    CONSTRAINT PK_Billing_Email_Subjects PRIMARY KEY (billing_type)
  );
END;

MERGE dbo.Billing_Email_Subjects AS target
USING (VALUES
  ('BM',  '4645 Mail Center - %{fiscal_year}.%{apmon} - BM - Brown Mail'),
  ('CSB', '4643 Warehouse - %{fiscal_year}.%{apmon} - CSB - Stores Billing'),
  ('GDS', '4641 Doc Pub - %{fiscal_year}.%{apmon} - GDS - Digital Services'),
  ('GPH', '4641 Doc Pub - %{fiscal_year}.%{apmon} - GPH - VcPrint'),
  ('GRP', '4641 Doc Pub - %{fiscal_year}.%{apmon} - GRP - Print to Mail - Graphics'),
  ('MCR', '4565 Mail Center - %{fiscal_year}.%{apmon} - MCR - Mail Center Receiving'),
  ('MNP', '4565 Mail Center - %{fiscal_year}.%{apmon} - MNP - Business Reply Mail'),
  ('MTP', '4565 Mail Center - %{fiscal_year}.%{apmon} - MTP - Metering'),
  ('PLT', '4643 Warehouse - %{fiscal_year}.%{apmon} - PLT - Pallet Storage'),
  ('PTP', '4645 Mail Center - %{fiscal_year}.%{apmon} - PTP - Print to Mail - Postage'),
  ('RCD', '4643 Doc Pub - %{fiscal_year}.%{apmon} - RCD - Records'),
  ('SCS', '4643 Warehouse - %{fiscal_year}.%{apmon} - SCS - Car Sales'),
  ('SRC', '4643 Warehouse - %{fiscal_year}.%{apmon} - SRC - Warehouse Receiving'),
  ('SSC', '4643 Warehouse - %{fiscal_year}.%{apmon} - SSC - Special Transactions'),
  ('SSI', '4643 Warehouse - %{fiscal_year}.%{apmon} - SSI - Sendsuite Shipping')
) AS source (billing_type, subject_format)
ON target.billing_type = source.billing_type
WHEN NOT MATCHED THEN
  INSERT (billing_type, subject_format)
  VALUES (source.billing_type, source.subject_format);

GRANT SELECT, INSERT, DELETE ON OBJECT::dbo.Billing_Email_Recipients TO [GSAETL];
GRANT SELECT, INSERT, UPDATE ON OBJECT::dbo.Billing_Email_Subjects TO [GSAETL];

COMMIT TRANSACTION;
