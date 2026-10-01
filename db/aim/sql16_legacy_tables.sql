-- AIM's legacy tables, moved off gsa-sql22 [GSA_Scan] to GSASQL16 [GSA Scan]
-- (2026-10-01). Same names, columns, keys and defaults as on gsa-sql22, so
-- the workers only change server and database. Safe to run again: a table
-- that already exists is left alone. Run by script/aim/copy_sql22_to_sql16.rb
-- as GSAETL, which may create tables in [GSA Scan].
--
-- gsa-sql22 hides two definitions from every AIM login; both were rebuilt
-- from the v1 code and the stored rows, and the copy script checks every
-- copied row against the source:
--   InvoiceConcatID     vendor.number.total.yyyy-mm-dd, blanks as UNKNOWN /
--                       UNKNOWN / 0.00 / 1900-01-01 (matches every stored row)
--   the two defaults    GETDATE() (pipeline_common.py)

-- A persisted computed column needs these on when the table is created and
-- whenever it is written; SSMS has them on, TinyTDS sessions do not.
SET ANSI_NULLS ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET QUOTED_IDENTIFIER ON;
SET NUMERIC_ROUNDABORT OFF;

IF OBJECT_ID(N'dbo.Aim_Invoices', N'U') IS NULL
CREATE TABLE dbo.Aim_Invoices (
  [ID] int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Aim_Invoices PRIMARY KEY CLUSTERED,
  [Budget Unit #] nvarchar(max) NULL,
  [Invoice Date] date NULL,
  [Vendor Name] nvarchar(max) NULL,
  [Remit to] nvarchar(max) NULL,
  [Invoice Number] nvarchar(max) NULL,
  [Invoice_Amt] nvarchar(max) NULL,
  [Credit Amount] nvarchar(max) NULL,
  [Sales_Tax] nvarchar(max) NULL,
  [BDO_DO_CT] nvarchar(max) NULL,
  [Program_Number] nvarchar(max) NULL,
  [Major_Program] nvarchar(max) NULL,
  [Fund] nvarchar(max) NULL,
  [Object] nvarchar(max) NULL,
  [Program] nvarchar(max) NULL,
  [Activity] nvarchar(max) NULL,
  [Function] nvarchar(max) NULL,
  [Phase] nvarchar(max) NULL,
  [Department] nvarchar(max) NULL,
  [Order_number] nvarchar(max) NULL,
  [Customer] nvarchar(max) NULL,
  [To_reviewers] nvarchar(max) NULL,
  [Fusion Queue] nvarchar(max) NULL,
  [Task] nvarchar(max) NULL,
  [BatchCreateDate] date NULL,
  [Order #] nvarchar(max) NULL,
  [PO Number] nvarchar(max) NULL,
  [Account Number] nvarchar(max) NULL,
  [BatchID] nvarchar(max) NULL,
  [timestamp] nvarchar(max) NULL,
  [User Name] nvarchar(max) NULL,
  [Subtotal] nvarchar(max) NULL,
  [Source] nvarchar(max) NULL,
  [Approved By] nvarchar(max) NULL,
  [Invoice Status] nvarchar(max) NULL,
  [Processed Date] date NULL,
  [ProcessedTimestamp] datetime NULL
);

IF OBJECT_ID(N'dbo.Aim_Processing_Logs', N'U') IS NULL
CREATE TABLE dbo.Aim_Processing_Logs (
  [ID] int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Aim_Processing_Logs PRIMARY KEY CLUSTERED,
  [FileName] nvarchar(max) NULL,
  [Submitter] nvarchar(max) NULL,
  [BU] nvarchar(max) NULL,
  [VendorName] nvarchar(max) NULL,
  [InvoiceNumber] nvarchar(max) NULL,
  [InvoiceTotal] nvarchar(max) NULL,
  [InvoiceDate] date NULL,
  [ExtractedMetadata] nvarchar(max) NULL,
  [Status] nvarchar(50) NULL,
  [ErrorMessage] nvarchar(max) NULL,
  [ProcessedTimestamp] datetime NULL CONSTRAINT DF_Aim_Processing_Logs_ProcessedTimestamp DEFAULT GETDATE(),
  [InvoiceConcatID] AS CAST(CONCAT(ISNULL([VendorName], 'UNKNOWN'), '.', ISNULL([InvoiceNumber], 'UNKNOWN'), '.',
                                   ISNULL([InvoiceTotal], '0.00'), '.',
                                   ISNULL(CONVERT(varchar(10), [InvoiceDate], 120), '1900-01-01')) AS nvarchar(450)) PERSISTED
);

IF OBJECT_ID(N'dbo.Aim_Vendor_Aliases', N'U') IS NULL
CREATE TABLE dbo.Aim_Vendor_Aliases (
  [ExtractedName] varchar(255) NOT NULL CONSTRAINT PK_Aim_Vendor_Aliases PRIMARY KEY CLUSTERED,
  [NormalizedName] varchar(255) NOT NULL,
  [DateLearned] datetime NULL CONSTRAINT DF_Aim_Vendor_Aliases_DateLearned DEFAULT GETDATE(),
  [Notes] nvarchar(max) NULL
);
