/* =====================================================================
   HSA ADOPTION CARD SEARCH -- schema for [GSA Scan] on the GSABSS server.

   Copied from CustomTools/Powershell/HSA_Adoption_card_search/sql/
   adoption_card_triangulation.sql with the database name corrected and the
   access-control section replaced by the roles Paperboy relies on. Every
   CREATE TABLE / INDEX is guarded so the script can be rerun. Needs an
   account with CREATE FUNCTION / PROCEDURE / VIEW and ALTER ANY ROLE on
   [GSA Scan]; the GSAETL service login cannot create code objects there.
   ===================================================================== */

/* =====================================================================
   ADOPTION CARD TRIANGULATION  --  Microsoft SQL Server 2016 SP1 or later
   (SP1 is the floor only because of CREATE OR ALTER. Deliberately avoids
    TRANSLATE, CONCAT_WS, STRING_AGG and TRIM, all of which are 2017+.
    The search proc uses STRING_SPLIT, which needs the database at
    compatibility level 130 or higher.)

   PART 1  (below)  : the HSA_Adopt_AdoptionCards table. Run this, key in sample cards.
   PART 2  (line ~60): functions, scoring, triangulation, search, audit.
                       Everything in Part 2 is derived from HSA_Adopt_AdoptionCards and can be
                       dropped and recreated freely. Do not run it until
                       there is sample data to test it against.

   After each batch of newly keyed cards:  EXEC dbo.HSA_Adopt_usp_RebuildCaseGroups;
   ===================================================================== */


/* =====================================================================
   PART 1  --  CORE TABLE
   ===================================================================== */

-- Everything below is created in THIS database. Without it, objects land in
-- whatever database the connection happens to be on (master, by default).
USE [GSA Scan];
GO
-- Sanity check before you run anything else -- should print GSA_Scan:
-- SELECT DB_NAME() AS CreatingObjectsIn;

IF OBJECT_ID('dbo.HSA_Adopt_AdoptionCards', 'U') IS NULL
CREATE TABLE dbo.HSA_Adopt_AdoptionCards (
    ID                     INT IDENTITY(1,1) PRIMARY KEY,
    CardType               NVARCHAR(20)  NOT NULL,  -- 'CHILD' | 'ADOPTIVE PARENTS' | 'BIRTH PARENTS'
    Child_BirthLast        NVARCHAR(200) NULL,
    Child_BirthFirst       NVARCHAR(200) NULL,
    Child_AdoptLast        NVARCHAR(200) NULL,
    Child_AdoptFirst       NVARCHAR(200) NULL,
    Child_DOB              DATE          NULL,
    BirthParent_1_Last     NVARCHAR(200) NULL,
    BirthParent_1_First    NVARCHAR(200) NULL,
    BirthParent_2_Last     NVARCHAR(200) NULL,
    BirthParent_2_First    NVARCHAR(200) NULL,
    AdoptParent_1_Last     NVARCHAR(200) NULL,
    AdoptParent_1_First    NVARCHAR(200) NULL,
    AdoptParent_2_Last     NVARCHAR(200) NULL,
    AdoptParent_2_First    NVARCHAR(200) NULL,
    Case_Number            NVARCHAR(200) NULL,      -- as written on the card
    CloseDate              DATE          NULL,
    FinalDate_FinalDecree  DATE          NULL,
    VEN_Number             NVARCHAR(200) NULL,
    A_Number               NVARCHAR(200) NULL,
    Notes                  NVARCHAR(MAX) NULL,      -- free text, can be long
    Filepath               NVARCHAR(400) NULL,      -- UNC path to the scanned PDF
    -- provenance of the keyed record; delete these two lines if not wanted
    CreatedAtUtc           DATETIME2(0)  NOT NULL CONSTRAINT DF_HSA_Adopt_AdoptionCards_At DEFAULT SYSUTCDATETIME(),
    CreatedBy              SYSNAME       NOT NULL CONSTRAINT DF_HSA_Adopt_AdoptionCards_By DEFAULT SUSER_SNAME(),
    -- UPPER() so 'Child' and 'CHILD' both pass even under a case-sensitive collation
    CONSTRAINT CK_HSA_Adopt_AdoptionCards_CardType CHECK (UPPER(CardType) IN (N'ADOPTIVE PARENTS', N'BIRTH PARENTS', N'CHILD'))
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_HSA_Adopt_AdoptionCards_Type' AND object_id = OBJECT_ID('dbo.HSA_Adopt_AdoptionCards'))
    CREATE INDEX IX_HSA_Adopt_AdoptionCards_Type ON dbo.HSA_Adopt_AdoptionCards(CardType);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_HSA_Adopt_AdoptionCards_DOB' AND object_id = OBJECT_ID('dbo.HSA_Adopt_AdoptionCards'))
    CREATE INDEX IX_HSA_Adopt_AdoptionCards_DOB  ON dbo.HSA_Adopt_AdoptionCards(Child_DOB);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_HSA_Adopt_AdoptionCards_Case' AND object_id = OBJECT_ID('dbo.HSA_Adopt_AdoptionCards'))
    CREATE INDEX IX_HSA_Adopt_AdoptionCards_Case ON dbo.HSA_Adopt_AdoptionCards(Case_Number);
GO


/* =====================================================================
   PART 2  --  everything below is derived from HSA_Adopt_AdoptionCards.
               Run only once sample cards are keyed in.
   ===================================================================== */

-- Repeated here because Part 2 is normally run in a later session than Part 1.
USE [GSA Scan];
GO

-- 2. HELPER FUNCTIONS ---------------------------------------------------
-- Digits only: '56-93-117, 600-4' -> '56931176004' ; 'A018332' -> '018332'
CREATE OR ALTER FUNCTION dbo.HSA_Adopt_fnDigitsOnly (@s NVARCHAR(MAX)) RETURNS NVARCHAR(100) AS
BEGIN
    IF @s IS NULL RETURN NULL;
    DECLARE @out NVARCHAR(100) = N'', @i INT = 1, @n INT = LEN(@s);
    WHILE @i <= @n AND LEN(@out) < 100
    BEGIN
        IF SUBSTRING(@s,@i,1) LIKE '[0-9]' SET @out += SUBSTRING(@s,@i,1);
        SET @i += 1;
    END
    RETURN NULLIF(@out, N'');
END;
GO

-- Name cleanup: uppercase, strip punctuation and (nickname) blocks, collapse spaces
CREATE OR ALTER FUNCTION dbo.HSA_Adopt_fnNormName (@s NVARCHAR(MAX)) RETURNS NVARCHAR(200) AS
BEGIN
    IF @s IS NULL RETURN NULL;
    WHILE CHARINDEX('(',@s) > 0 AND CHARINDEX(')',@s) > CHARINDEX('(',@s)
        SET @s = STUFF(@s, CHARINDEX('(',@s), CHARINDEX(')',@s)-CHARINDEX('(',@s)+1, '');
    -- Nested REPLACE rather than TRANSLATE: TRANSLATE is SQL Server 2017+ only.
    SET @s = UPPER(@s);
    SET @s = REPLACE(@s, N'.',  N' ');
    SET @s = REPLACE(@s, N',',  N' ');
    SET @s = REPLACE(@s, N'-',  N' ');
    SET @s = REPLACE(@s, N'''', N' ');
    SET @s = REPLACE(@s, N'"',  N' ');
    WHILE CHARINDEX('  ',@s) > 0 SET @s = REPLACE(@s,'  ',' ');
    RETURN NULLIF(LTRIM(RTRIM(@s)), N'');
END;
GO

-- Case-number suffix match ('931176004' is the tail of '56931176004')
-- @MinLen: lower it if 1950s-era case numbers on your cards are shorter than 6 digits.
CREATE OR ALTER FUNCTION dbo.HSA_Adopt_fnCaseMatch (@a NVARCHAR(100), @b NVARCHAR(100)) RETURNS BIT AS
BEGIN
    DECLARE @MinLen INT = 6;
    IF @a IS NULL OR @b IS NULL OR LEN(@a) < @MinLen OR LEN(@b) < @MinLen RETURN 0;
    IF LEN(@a) <= LEN(@b) AND RIGHT(@b, LEN(@a)) = @a RETURN 1;
    IF LEN(@b) <  LEN(@a) AND RIGHT(@a, LEN(@b)) = @b RETURN 1;
    RETURN 0;
END;
GO

-- DOB score by how many of the three components (year, month, day) agree.
-- Two unrelated cards agree on month+day about 1 time in 360, year+day about
-- 1 in 600, year+month about 1 in 240 -- all roughly equally rare, so all three
-- two-of-three cases score the same. Each is also an equally plausible single
-- mistyped field, which is what we are trying to survive.
-- No year-gap limit: a transposed year (1959 -> 1995) is the same class of
-- error as an adjacent-digit slip, and month+day agreeing is rare either way.
CREATE OR ALTER FUNCTION dbo.HSA_Adopt_fnDobScore (@a DATE, @b DATE) RETURNS INT AS
BEGIN
    IF @a IS NULL OR @b IS NULL RETURN 0;
    DECLARE @m INT =
          CASE WHEN YEAR(@a)  = YEAR(@b)  THEN 1 ELSE 0 END
        + CASE WHEN MONTH(@a) = MONTH(@b) THEN 1 ELSE 0 END
        + CASE WHEN DAY(@a)   = DAY(@b)   THEN 1 ELSE 0 END;
    RETURN CASE @m
             WHEN 3 THEN 40      -- identical
             WHEN 2 THEN 25      -- one component mistyped; stays below the AUTO floor
             WHEN 1 THEN 5       -- two components differ; weak, cannot carry a pair alone
             ELSE 0 END;
END;
GO

-- Placeholder / non-identifying names that must never score as a match.
-- 'Baby Boy' appears on hundreds of unrelated cards by data-entry convention.
CREATE OR ALTER FUNCTION dbo.HSA_Adopt_fnIsPlaceholder (@s NVARCHAR(200)) RETURNS BIT AS
BEGIN
    IF @s IS NULL RETURN 1;
    IF @s IN (N'BABY', N'BABY BOY', N'BABY GIRL', N'BABYBOY', N'BABYGIRL',
              N'INFANT', N'MALE', N'FEMALE', N'TWIN', N'TWIN A', N'TWIN B',
              N'UNKNOWN', N'UNK', N'NONE', N'NA', N'N A')
        RETURN 1;
    RETURN 0;
END;
GO

-- Normalized "FIRSTNAME LASTNAME", using only the FIRST given-name token.
-- Middle names and initials are dropped on purpose: the same parent is written
-- 'Mika' on one card and 'Mika L.' on another, and keeping the middle initial
-- silently demotes a real full-name match to a surname-only one.
-- NULL if either half is missing or the first name is a placeholder, so a
-- full-name match always means a real identification.
CREATE OR ALTER FUNCTION dbo.HSA_Adopt_fnFullName (@first NVARCHAR(200), @last NVARCHAR(200))
RETURNS NVARCHAR(401) AS
BEGIN
    DECLARE @f NVARCHAR(200) = dbo.HSA_Adopt_fnNormName(@first),
            @l NVARCHAR(200) = dbo.HSA_Adopt_fnNormName(@last);
    IF @f IS NULL OR @l IS NULL RETURN NULL;
    IF dbo.HSA_Adopt_fnIsPlaceholder(@f) = 1 RETURN NULL;              -- 'BABY BOY' etc.
    IF CHARINDEX(N' ', @f) > 0 SET @f = LEFT(@f, CHARINDEX(N' ', @f) - 1);
    IF dbo.HSA_Adopt_fnIsPlaceholder(@f) = 1 RETURN NULL;              -- 'BABY' alone
    RETURN @f + N' ' + @l;
END;
GO

-- Does one card's Notes reference the other card's case number?
--   2 = the case number's last 5 digits appear in the Notes exactly
--   1 = they appear with ONE digit wrong (confirmed error class: a handwritten
--       9 keyed as 0). Recovers links a keyer's slip would otherwise destroy.
--   0 = no reference
-- Matched on the last 5 digits, not the whole string, because the Notes carry
-- the distinctive tail ('9-2011') of a longer case number ('56 9-2011') and
-- HSA_Adopt_fnDigitsOnly merges every number in the Notes into one blob.
CREATE OR ALTER FUNCTION dbo.HSA_Adopt_fnNotesRef (@caseDigits NVARCHAR(100), @notesDigits NVARCHAR(100))
RETURNS TINYINT AS
BEGIN
    IF @caseDigits IS NULL OR @notesDigits IS NULL OR LEN(@caseDigits) < 5 RETURN 0;
    DECLARE @tail NVARCHAR(5) = RIGHT(@caseDigits, 5);
    IF CHARINDEX(@tail, @notesDigits) > 0 RETURN 2;
    DECLARE @i INT = 1;
    WHILE @i <= 5                          -- '_' is LIKE's single-character wildcard
    BEGIN
        IF @notesDigits LIKE N'%' + STUFF(@tail, @i, 1, N'_') + N'%' RETURN 1;
        SET @i += 1;
    END
    RETURN 0;
END;
GO

-- 3. NORMALIZED CARDS (materialized, not a view) ------------------------
-- A view would re-run the scalar UDFs once per row per predicate on every
-- comparison and every search. This computes them once per rebuild and indexes them.
IF OBJECT_ID('dbo.HSA_Adopt_AdoptionCardsNorm', 'U') IS NULL
CREATE TABLE dbo.HSA_Adopt_AdoptionCardsNorm (
    ID          INT PRIMARY KEY,
    CardType    NVARCHAR(20)  NOT NULL,
    Child_DOB   DATE          NULL,
    CaseDigits  NVARCHAR(100) NULL,
    NotesDigits NVARCHAR(100) NULL,      -- catches case numbers written into Notes
    VENDigits   NVARCHAR(100) NULL,
    ADigits     NVARCHAR(100) NULL,
    CBL NVARCHAR(200) NULL, CBF NVARCHAR(200) NULL,
    CAL NVARCHAR(200) NULL, CAF NVARCHAR(200) NULL,
    CBF_Real NVARCHAR(200) NULL,         -- child first name, NULL when 'BABY BOY' etc.
    CAF_Real NVARCHAR(200) NULL,
    BP1_L NVARCHAR(200) NULL, BP2_L NVARCHAR(200) NULL,
    AP1_L NVARCHAR(200) NULL, AP2_L NVARCHAR(200) NULL,
    BP1_F NVARCHAR(200) NULL, BP2_F NVARCHAR(200) NULL,   -- parents' first names, for
    AP1_F NVARCHAR(200) NULL, AP2_F NVARCHAR(200) NULL,   -- role-specific searching
    BP1_FULL NVARCHAR(401) NULL, BP2_FULL NVARCHAR(401) NULL,
    AP1_FULL NVARCHAR(401) NULL, AP2_FULL NVARCHAR(401) NULL,
    CBL_SX CHAR(4) NULL, CAL_SX CHAR(4) NULL,
    BP1_SX CHAR(4) NULL, BP2_SX CHAR(4) NULL,
    AP1_SX CHAR(4) NULL, AP2_SX CHAR(4) NULL,
    AllNames NVARCHAR(2600) NULL         -- every name on the card, for free-text search
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_HSA_Adopt_ACN_Type' AND object_id = OBJECT_ID('dbo.HSA_Adopt_AdoptionCardsNorm'))
    CREATE INDEX IX_HSA_Adopt_ACN_Type  ON dbo.HSA_Adopt_AdoptionCardsNorm(CardType) INCLUDE (Child_DOB);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_HSA_Adopt_ACN_DOB' AND object_id = OBJECT_ID('dbo.HSA_Adopt_AdoptionCardsNorm'))
    CREATE INDEX IX_HSA_Adopt_ACN_DOB   ON dbo.HSA_Adopt_AdoptionCardsNorm(Child_DOB);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_HSA_Adopt_ACN_Case' AND object_id = OBJECT_ID('dbo.HSA_Adopt_AdoptionCardsNorm'))
    CREATE INDEX IX_HSA_Adopt_ACN_Case  ON dbo.HSA_Adopt_AdoptionCardsNorm(CaseDigits);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_HSA_Adopt_ACN_VEN' AND object_id = OBJECT_ID('dbo.HSA_Adopt_AdoptionCardsNorm'))
    CREATE INDEX IX_HSA_Adopt_ACN_VEN   ON dbo.HSA_Adopt_AdoptionCardsNorm(VENDigits);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_HSA_Adopt_ACN_A' AND object_id = OBJECT_ID('dbo.HSA_Adopt_AdoptionCardsNorm'))
    CREATE INDEX IX_HSA_Adopt_ACN_A     ON dbo.HSA_Adopt_AdoptionCardsNorm(ADigits);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_HSA_Adopt_ACN_CBLSX' AND object_id = OBJECT_ID('dbo.HSA_Adopt_AdoptionCardsNorm'))
    CREATE INDEX IX_HSA_Adopt_ACN_CBLSX ON dbo.HSA_Adopt_AdoptionCardsNorm(CBL_SX);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_HSA_Adopt_ACN_CALSX' AND object_id = OBJECT_ID('dbo.HSA_Adopt_AdoptionCardsNorm'))
    CREATE INDEX IX_HSA_Adopt_ACN_CALSX ON dbo.HSA_Adopt_AdoptionCardsNorm(CAL_SX);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_HSA_Adopt_ACN_BP1SX' AND object_id = OBJECT_ID('dbo.HSA_Adopt_AdoptionCardsNorm'))
    CREATE INDEX IX_HSA_Adopt_ACN_BP1SX ON dbo.HSA_Adopt_AdoptionCardsNorm(BP1_SX);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_HSA_Adopt_ACN_BP2SX' AND object_id = OBJECT_ID('dbo.HSA_Adopt_AdoptionCardsNorm'))
    CREATE INDEX IX_HSA_Adopt_ACN_BP2SX ON dbo.HSA_Adopt_AdoptionCardsNorm(BP2_SX);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_HSA_Adopt_ACN_AP1SX' AND object_id = OBJECT_ID('dbo.HSA_Adopt_AdoptionCardsNorm'))
    CREATE INDEX IX_HSA_Adopt_ACN_AP1SX ON dbo.HSA_Adopt_AdoptionCardsNorm(AP1_SX);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_HSA_Adopt_ACN_AP2SX' AND object_id = OBJECT_ID('dbo.HSA_Adopt_AdoptionCardsNorm'))
    CREATE INDEX IX_HSA_Adopt_ACN_AP2SX ON dbo.HSA_Adopt_AdoptionCardsNorm(AP2_SX);
GO

CREATE OR ALTER PROCEDURE dbo.HSA_Adopt_usp_RebuildAdoptionCardsNorm AS
BEGIN
    SET NOCOUNT ON;
    TRUNCATE TABLE dbo.HSA_Adopt_AdoptionCardsNorm;
    INSERT INTO dbo.HSA_Adopt_AdoptionCardsNorm
        (ID, CardType, Child_DOB, CaseDigits, NotesDigits, VENDigits, ADigits,
         CBL, CBF, CAL, CAF, CBF_Real, CAF_Real,
         BP1_L, BP2_L, AP1_L, AP2_L, BP1_F, BP2_F, AP1_F, AP2_F,
         BP1_FULL, BP2_FULL, AP1_FULL, AP2_FULL,
         CBL_SX, CAL_SX, BP1_SX, BP2_SX, AP1_SX, AP2_SX, AllNames)
    SELECT c.ID,
           UPPER(LTRIM(RTRIM(c.CardType))),
           c.Child_DOB,
           dbo.HSA_Adopt_fnDigitsOnly(c.Case_Number),
           dbo.HSA_Adopt_fnDigitsOnly(c.Notes),
           dbo.HSA_Adopt_fnDigitsOnly(c.VEN_Number),
           dbo.HSA_Adopt_fnDigitsOnly(c.A_Number),
           dbo.HSA_Adopt_fnNormName(c.Child_BirthLast),  dbo.HSA_Adopt_fnNormName(c.Child_BirthFirst),
           dbo.HSA_Adopt_fnNormName(c.Child_AdoptLast),  dbo.HSA_Adopt_fnNormName(c.Child_AdoptFirst),
           CASE WHEN dbo.HSA_Adopt_fnIsPlaceholder(dbo.HSA_Adopt_fnNormName(c.Child_BirthFirst)) = 1
                THEN NULL ELSE dbo.HSA_Adopt_fnNormName(c.Child_BirthFirst) END,
           CASE WHEN dbo.HSA_Adopt_fnIsPlaceholder(dbo.HSA_Adopt_fnNormName(c.Child_AdoptFirst)) = 1
                THEN NULL ELSE dbo.HSA_Adopt_fnNormName(c.Child_AdoptFirst) END,
           dbo.HSA_Adopt_fnNormName(c.BirthParent_1_Last), dbo.HSA_Adopt_fnNormName(c.BirthParent_2_Last),
           dbo.HSA_Adopt_fnNormName(c.AdoptParent_1_Last), dbo.HSA_Adopt_fnNormName(c.AdoptParent_2_Last),
           dbo.HSA_Adopt_fnNormName(c.BirthParent_1_First), dbo.HSA_Adopt_fnNormName(c.BirthParent_2_First),
           dbo.HSA_Adopt_fnNormName(c.AdoptParent_1_First), dbo.HSA_Adopt_fnNormName(c.AdoptParent_2_First),
           dbo.HSA_Adopt_fnFullName(c.BirthParent_1_First, c.BirthParent_1_Last),
           dbo.HSA_Adopt_fnFullName(c.BirthParent_2_First, c.BirthParent_2_Last),
           dbo.HSA_Adopt_fnFullName(c.AdoptParent_1_First, c.AdoptParent_1_Last),
           dbo.HSA_Adopt_fnFullName(c.AdoptParent_2_First, c.AdoptParent_2_Last),
           SOUNDEX(dbo.HSA_Adopt_fnNormName(c.Child_BirthLast)),
           SOUNDEX(dbo.HSA_Adopt_fnNormName(c.Child_AdoptLast)),
           SOUNDEX(dbo.HSA_Adopt_fnNormName(c.BirthParent_1_Last)),
           SOUNDEX(dbo.HSA_Adopt_fnNormName(c.BirthParent_2_Last)),
           SOUNDEX(dbo.HSA_Adopt_fnNormName(c.AdoptParent_1_Last)),
           SOUNDEX(dbo.HSA_Adopt_fnNormName(c.AdoptParent_2_Last)),
           -- CONCAT (2012+) rather than CONCAT_WS (2017+). CONCAT treats NULL as
           -- '', so missing names just leave extra spaces -- harmless for LIKE.
           CONCAT(c.Child_BirthFirst,     N' ', c.Child_BirthLast,     N' ',
                  c.Child_AdoptFirst,     N' ', c.Child_AdoptLast,     N' ',
                  c.BirthParent_1_First,  N' ', c.BirthParent_1_Last,  N' ',
                  c.BirthParent_2_First,  N' ', c.BirthParent_2_Last,  N' ',
                  c.AdoptParent_1_First,  N' ', c.AdoptParent_1_Last,  N' ',
                  c.AdoptParent_2_First,  N' ', c.AdoptParent_2_Last)
    FROM dbo.HSA_Adopt_AdoptionCards c;
END;
GO

CREATE OR ALTER VIEW HSA_Adopt_vAdoptionCards AS SELECT * FROM dbo.HSA_Adopt_AdoptionCardsNorm;
GO

-- 3b. KEYING QUALITY CHECKS ---------------------------------------------
-- Scanning happens one card type at a time, so a misunderstood convention
-- affects a WHOLE type uniformly. Run these after the first few hundred cards
-- of each stage, while the fix is a conversation instead of a re-key project.
-- Requires only Part 1 plus sections 2-3, and starts with:
--     EXEC dbo.HSA_Adopt_usp_RebuildAdoptionCardsNorm;
/*
-- 0. Blank dates that became 1900-01-01 on import (SQL Server converts an
--    empty string to the base date). They show up on cards and score as an
--    exact DOB match between two blank cards. Null them, then rebuild.
--    Full script with counts: fix_1900_dates.sql
SELECT ID, CardType, Child_DOB, CloseDate, FinalDate_FinalDecree
FROM dbo.HSA_Adopt_AdoptionCards
WHERE Child_DOB = '19000101' OR CloseDate = '19000101' OR FinalDate_FinalDecree = '19000101';

-- 1. Cards with nothing to match on: no DOB, no case digits, no VEN/A#.
--    These can only ever be linked by name, so a rising count is a warning.
SELECT CardType, COUNT(*) AS Unmatchable
FROM dbo.HSA_Adopt_AdoptionCardsNorm
WHERE Child_DOB IS NULL AND CaseDigits IS NULL AND VENDigits IS NULL AND ADigits IS NULL
GROUP BY CardType;

-- 2. Case-number length spread. A new length appearing mid-batch usually means
--    a format change on the cards, or a keyer dropping or adding a segment.
SELECT CardType, LEN(CaseDigits) AS Digits, COUNT(*) AS Cards
FROM dbo.HSA_Adopt_AdoptionCardsNorm WHERE CaseDigits IS NOT NULL
GROUP BY CardType, LEN(CaseDigits) ORDER BY CardType, Digits;

-- 3. Placeholder child first names ('Baby Boy' etc). Expected -- just know the rate.
SELECT CardType, COUNT(*) AS Cards,
       SUM(CASE WHEN CBF_Real IS NULL AND CBL IS NOT NULL THEN 1 ELSE 0 END) AS PlaceholderFirst
FROM dbo.HSA_Adopt_AdoptionCardsNorm GROUP BY CardType;

-- 4. Impossible dates -- catches year typos while the card is still on the desk.
SELECT ID, Child_DOB, CloseDate, FinalDate_FinalDecree
FROM dbo.HSA_Adopt_AdoptionCards
WHERE Child_DOB < '1930-01-01' OR Child_DOB > GETDATE()
   OR FinalDate_FinalDecree < Child_DOB OR CloseDate < Child_DOB;

-- 5. Same case number keyed twice in one card type: a duplicate card, or a
--    value copy-pasted down the spreadsheet.
SELECT CardType, CaseDigits, COUNT(*) AS n
FROM dbo.HSA_Adopt_AdoptionCardsNorm WHERE CaseDigits IS NOT NULL
GROUP BY CardType, CaseDigits HAVING COUNT(*) > 1;

-- 6. Scan paths missing, or the same PDF claimed by two cards.
SELECT COUNT(*) AS CardsWithNoFilepath FROM dbo.HSA_Adopt_AdoptionCards WHERE Filepath IS NULL;
SELECT Filepath, COUNT(*) AS n FROM dbo.HSA_Adopt_AdoptionCards
WHERE Filepath IS NOT NULL GROUP BY Filepath HAVING COUNT(*) > 1;

-- 7. Birth and adopted names identical -- the value-copied-across-the-row error.
SELECT ID, Child_BirthFirst, Child_AdoptFirst FROM dbo.HSA_Adopt_AdoptionCards
WHERE Child_BirthFirst = Child_AdoptFirst AND Child_BirthFirst IS NOT NULL;

-- 8. AFTER STAGE 2 (adopt + birth keyed, no child cards yet). HSA_Adopt_CaseGroups will
--    still be empty -- it is built per CHILD card -- but the scoring itself is
--    already working, and these pairs exercise VEN/A#, DOB and parent names.
SELECT Verdict, COUNT(*) AS Pairs FROM HSA_Adopt_vPairTotals
WHERE Type_A = 'ADOPTIVE PARENTS' AND Type_B = 'BIRTH PARENTS'
GROUP BY Verdict;
*/

-- 4. PAIRWISE SCORING ---------------------------------------------------
-- Hard identifiers : VEN/A# 35 | DOB up to 40 | case number 30 | case no. in Notes 10
-- Names            : child surname 20 exact / 15 soundex | child first 10
--                    each parent set 45 both-full / 35 one-full / 20 exact surname / 15 soundex
CREATE OR ALTER VIEW HSA_Adopt_vPairScores AS
SELECT a.ID AS ID_A, a.CardType AS Type_A, b.ID AS ID_B, b.CardType AS Type_B,

  CASE WHEN (a.VENDigits IS NOT NULL AND a.VENDigits IN (b.VENDigits, b.ADigits))
         OR (a.ADigits   IS NOT NULL AND a.ADigits   IN (b.VENDigits, b.ADigits))
       THEN 35 ELSE 0 END                                        AS s_venA,

  dbo.HSA_Adopt_fnDobScore(a.Child_DOB, b.Child_DOB)                       AS s_dob,

  30 * dbo.HSA_Adopt_fnCaseMatch(a.CaseDigits, b.CaseDigits)               AS s_case,

  -- One card's Notes referencing the other's case number. See HSA_Adopt_fnNotesRef.
  -- Scores 10 whether the reference is exact or one digit off, but only an
  -- EXACT reference counts as hard evidence -- a fuzzy one is 40x more likely
  -- to be coincidence, and must not authorize an automatic link by itself.
  CASE WHEN nr.Ref >= 1 THEN 10 ELSE 0 END                       AS s_notescase,
  CASE WHEN nr.Ref  = 2 THEN 10 ELSE 0 END                       AS s_noteshard,

  CASE WHEN (a.CBL IS NOT NULL AND a.CBL = b.CBL)
         OR (a.CAL IS NOT NULL AND a.CAL = b.CAL)            THEN 20
       WHEN a.CBL_SX = b.CBL_SX OR a.CAL_SX = b.CAL_SX       THEN 15
       ELSE 0 END                                                AS s_childlast,

  CASE WHEN (a.CBF_Real IS NOT NULL AND a.CBF_Real = b.CBF_Real)
         OR (a.CAF_Real IS NOT NULL AND a.CAF_Real = b.CAF_Real) THEN 10
       ELSE 0 END                                                AS s_childfirst,

  -- BIRTH PARENTS, compared as a set, tiered by strength of the name evidence.
  -- 45 and 40 both mean "the sets match COMPLETELY"; they differ only in how
  -- many names had to agree, which is how much coincidence they rule out.
  CASE WHEN a.BP1_FULL IS NOT NULL AND a.BP2_FULL IS NOT NULL
            AND b.BP1_FULL IS NOT NULL AND b.BP2_FULL IS NOT NULL
            AND a.BP1_FULL IN (b.BP1_FULL, b.BP2_FULL)
            AND a.BP2_FULL IN (b.BP1_FULL, b.BP2_FULL)                          THEN 45
       -- exactly ONE parent named on each card, and it is the same person
       -- (birth father unknown, single-parent adoption)
       WHEN (CASE WHEN a.BP1_FULL IS NULL THEN 0 ELSE 1 END
           + CASE WHEN a.BP2_FULL IS NULL THEN 0 ELSE 1 END) = 1
        AND (CASE WHEN b.BP1_FULL IS NULL THEN 0 ELSE 1 END
           + CASE WHEN b.BP2_FULL IS NULL THEN 0 ELSE 1 END) = 1
        AND COALESCE(a.BP1_FULL, a.BP2_FULL) = COALESCE(b.BP1_FULL, b.BP2_FULL) THEN 40
       WHEN (a.BP1_FULL IS NOT NULL AND a.BP1_FULL IN (b.BP1_FULL, b.BP2_FULL))
         OR (a.BP2_FULL IS NOT NULL AND a.BP2_FULL IN (b.BP1_FULL, b.BP2_FULL))  THEN 35
       WHEN (a.BP1_L IS NOT NULL AND a.BP1_L IN (b.BP1_L, b.BP2_L))
         OR (a.BP2_L IS NOT NULL AND a.BP2_L IN (b.BP1_L, b.BP2_L))              THEN 20
       WHEN a.BP1_SX IN (b.BP1_SX, b.BP2_SX)
         OR a.BP2_SX IN (b.BP1_SX, b.BP2_SX)                                     THEN 15
       ELSE 0 END                                                AS s_birthparent,

  -- ADOPTIVE PARENTS, same tiers, plus child's adoptive surname vs parent surname.
  -- The 45/35 tiers are what link 1950s cards that have no DOB, case number or A#.
  CASE WHEN a.AP1_FULL IS NOT NULL AND a.AP2_FULL IS NOT NULL
            AND b.AP1_FULL IS NOT NULL AND b.AP2_FULL IS NOT NULL
            AND a.AP1_FULL IN (b.AP1_FULL, b.AP2_FULL)
            AND a.AP2_FULL IN (b.AP1_FULL, b.AP2_FULL)                          THEN 45
       -- single adoptive parent named on each card, and it is the same person
       WHEN (CASE WHEN a.AP1_FULL IS NULL THEN 0 ELSE 1 END
           + CASE WHEN a.AP2_FULL IS NULL THEN 0 ELSE 1 END) = 1
        AND (CASE WHEN b.AP1_FULL IS NULL THEN 0 ELSE 1 END
           + CASE WHEN b.AP2_FULL IS NULL THEN 0 ELSE 1 END) = 1
        AND COALESCE(a.AP1_FULL, a.AP2_FULL) = COALESCE(b.AP1_FULL, b.AP2_FULL) THEN 40
       WHEN (a.AP1_FULL IS NOT NULL AND a.AP1_FULL IN (b.AP1_FULL, b.AP2_FULL))
         OR (a.AP2_FULL IS NOT NULL AND a.AP2_FULL IN (b.AP1_FULL, b.AP2_FULL))  THEN 35
       WHEN (a.AP1_L IS NOT NULL AND a.AP1_L IN (b.AP1_L, b.AP2_L))
         OR (a.AP2_L IS NOT NULL AND a.AP2_L IN (b.AP1_L, b.AP2_L))
         OR (a.CAL   IS NOT NULL AND a.CAL   IN (b.AP1_L, b.AP2_L))
         OR (b.CAL   IS NOT NULL AND b.CAL   IN (a.AP1_L, a.AP2_L))              THEN 20
       WHEN a.AP1_SX IN (b.AP1_SX, b.AP2_SX)
         OR a.AP2_SX IN (b.AP1_SX, b.AP2_SX)
         OR a.CAL_SX IN (b.AP1_SX, b.AP2_SX)
         OR b.CAL_SX IN (a.AP1_SX, a.AP2_SX)                                     THEN 15
       ELSE 0 END                                                AS s_adoptparent

FROM dbo.HSA_Adopt_AdoptionCardsNorm a
JOIN dbo.HSA_Adopt_AdoptionCardsNorm b
  ON a.CardType < b.CardType     -- ADOPTIVE PARENTS < BIRTH PARENTS < CHILD; each pair once
 -- BLOCKING: only compare pairs sharing at least one cheap signal.
 -- The parent-name signals are required: without them the pairs the tiered
 -- parent scoring above exists to rescue are never compared at all.
 -- Any TWO of {year, month, day} agreeing admits the pair. The old form listed
 -- month+day and year+day only, so a pair whose sole date signal was year+month
 -- was never compared even though HSA_Adopt_fnDobScore would have credited it.
 -- NULL-safe: a missing DOB scores 0 on every component and blocks nothing.
 AND (   (  CASE WHEN YEAR(a.Child_DOB)  = YEAR(b.Child_DOB)  THEN 1 ELSE 0 END
          + CASE WHEN MONTH(a.Child_DOB) = MONTH(b.Child_DOB) THEN 1 ELSE 0 END
          + CASE WHEN DAY(a.Child_DOB)   = DAY(b.Child_DOB)   THEN 1 ELSE 0 END ) >= 2
      OR dbo.HSA_Adopt_fnCaseMatch(a.CaseDigits, b.CaseDigits) = 1
      OR a.VENDigits IN (b.VENDigits, b.ADigits)
      OR a.ADigits   IN (b.VENDigits, b.ADigits)
      OR a.CBL_SX = b.CBL_SX
      OR a.CAL_SX = b.CAL_SX
      OR a.AP1_SX IN (b.AP1_SX, b.AP2_SX) OR a.AP2_SX IN (b.AP1_SX, b.AP2_SX)
      OR a.BP1_SX IN (b.BP1_SX, b.BP2_SX) OR a.BP2_SX IN (b.BP1_SX, b.BP2_SX)
      OR a.CAL_SX IN (b.AP1_SX, b.AP2_SX) OR b.CAL_SX IN (a.AP1_SX, a.AP2_SX)
      OR a.CBL_SX IN (b.BP1_SX, b.BP2_SX) OR b.CBL_SX IN (a.BP1_SX, a.BP2_SX) )
CROSS APPLY (SELECT MAX(v) AS Ref FROM (VALUES (dbo.HSA_Adopt_fnNotesRef(a.CaseDigits, b.NotesDigits)),
                                               (dbo.HSA_Adopt_fnNotesRef(b.CaseDigits, a.NotesDigits))) x(v)) nr;
GO

CREATE OR ALTER VIEW HSA_Adopt_vPairTotals AS
SELECT p.*, v.HardEvidence, v.Score,
       CASE
         -- WEAK-PAIR GATE. A CHILD card and a parent card that agree on no
         -- identifier at all and on no form of the CHILD's own surname are not
         -- the same case, however well the parent block agrees -- that is
         -- precisely what a parent row shifted onto the wrong card looks like,
         -- and without this gate such a pair can outscore the true match.
         WHEN p.Type_B = 'CHILD' AND v.HardEvidence = 0
          AND p.s_notescase = 0 AND p.s_childlast = 0                            THEN 'NO'
         -- AUTO requires a hard identifier OR a COMPLETE parent-set match.
         -- Surnames alone, however many agree, only ever reach REVIEW.
         -- The two parent thresholds differ deliberately. Adoptive parents at 40
         -- lets a single-adoptive-parent case link automatically. Birth parents
         -- stay at 45, because siblings share a birth mother by definition: two
         -- children of the same single mother would otherwise auto-link to each
         -- other's card whenever the correct card is missing or not yet keyed.
         WHEN v.Score >= 70
          AND (v.HardEvidence >= 30 OR p.s_adoptparent >= 40
                                    OR p.s_birthparent >= 45)                    THEN 'AUTO'
         WHEN v.Score >= 45                                                      THEN 'REVIEW'
         ELSE 'NO' END                                                           AS Verdict
FROM HSA_Adopt_vPairScores p
CROSS APPLY (VALUES (
        p.s_venA + p.s_dob + p.s_case + p.s_noteshard,          -- HardEvidence
        p.s_venA + p.s_dob + p.s_case + p.s_notescase
      + p.s_childlast + p.s_childfirst + p.s_birthparent + p.s_adoptparent
     )) v(HardEvidence, Score);
GO

-- 5. TRIANGULATION ------------------------------------------------------
-- Human decisions live here, NOT in HSA_Adopt_CaseGroups, so that rebuilding the groups
-- after each keying batch never destroys review sign-off.
IF OBJECT_ID('dbo.HSA_Adopt_CaseReviewOverrides', 'U') IS NULL
CREATE TABLE dbo.HSA_Adopt_CaseReviewOverrides (
    ChildCardID  INT PRIMARY KEY,
    AdoptCardID  INT NULL,
    BirthCardID  INT NULL,
    Decision     NVARCHAR(12) NOT NULL,      -- CONFIRMED | REJECTED
    ReviewedBy   NVARCHAR(200) NOT NULL,
    ReviewedDate DATE NOT NULL CONSTRAINT DF_HSA_Adopt_CRO_Date DEFAULT CAST(GETDATE() AS DATE),
    ReviewNote   NVARCHAR(500) NULL,
    CONSTRAINT CK_HSA_Adopt_CRO_Decision CHECK (Decision IN (N'CONFIRMED', N'REJECTED'))
);
GO

IF OBJECT_ID('dbo.HSA_Adopt_CaseGroups', 'U') IS NULL
CREATE TABLE dbo.HSA_Adopt_CaseGroups (
    GroupID          INT IDENTITY(1,1) PRIMARY KEY,
    ChildCardID      INT NOT NULL,
    AdoptCardID      INT NULL,
    BirthCardID      INT NULL,
    ScoreChildAdopt  INT NULL,
    ScoreChildBirth  INT NULL,
    ScoreAdoptBirth  INT NULL,                -- corroboration between the two parent cards
    RunnerUpAdopt    INT NULL,                -- second-best score, so ties are visible
    RunnerUpBirth    INT NULL,
    Ambiguous        BIT NOT NULL CONSTRAINT DF_HSA_Adopt_CG_Amb DEFAULT 0,
    Status           NVARCHAR(12) NOT NULL,   -- AUTO / REVIEW / MANUAL / CONFIRMED
    Conflicts        NVARCHAR(500) NULL,
    ReviewedBy       NVARCHAR(200) NULL,
    ReviewedDate     DATE NULL,
    RunAtUtc         DATETIME2(0) NOT NULL CONSTRAINT DF_HSA_Adopt_CG_Run DEFAULT SYSUTCDATETIME()
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_HSA_Adopt_CG_Child' AND object_id = OBJECT_ID('dbo.HSA_Adopt_CaseGroups'))
    CREATE INDEX IX_HSA_Adopt_CG_Child ON dbo.HSA_Adopt_CaseGroups(ChildCardID);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_HSA_Adopt_CG_Adopt' AND object_id = OBJECT_ID('dbo.HSA_Adopt_CaseGroups'))
    CREATE INDEX IX_HSA_Adopt_CG_Adopt ON dbo.HSA_Adopt_CaseGroups(AdoptCardID);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_HSA_Adopt_CG_Birth' AND object_id = OBJECT_ID('dbo.HSA_Adopt_CaseGroups'))
    CREATE INDEX IX_HSA_Adopt_CG_Birth ON dbo.HSA_Adopt_CaseGroups(BirthCardID);
GO

CREATE OR ALTER PROCEDURE dbo.HSA_Adopt_usp_RebuildCaseGroups
    @AmbiguityMargin INT = 5     -- top two candidates this close => REVIEW, never AUTO
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.HSA_Adopt_usp_RebuildAdoptionCardsNorm;

    BEGIN TRAN;
    DELETE FROM dbo.HSA_Adopt_CaseGroups;

    ;WITH Ranked AS (
        SELECT p.ID_B AS ChildID, p.Type_A, p.ID_A AS OtherID, p.Score, p.Verdict,
               ROW_NUMBER() OVER (PARTITION BY p.ID_B, p.Type_A
                                  ORDER BY p.Score DESC, p.ID_A ASC) AS rn  -- deterministic
        FROM HSA_Adopt_vPairTotals p
        WHERE p.Type_B = 'CHILD' AND p.Score >= 45 AND p.Verdict <> 'NO'   -- excludes weak pairs
    ),
    Top1 AS (SELECT ChildID, Type_A, OtherID, Score, Verdict FROM Ranked WHERE rn = 1),
    Top2 AS (SELECT ChildID, Type_A, Score FROM Ranked WHERE rn = 2)
    INSERT INTO dbo.HSA_Adopt_CaseGroups
        (ChildCardID, AdoptCardID, BirthCardID, ScoreChildAdopt, ScoreChildBirth,
         ScoreAdoptBirth, RunnerUpAdopt, RunnerUpBirth, Ambiguous, Status, Conflicts)
    SELECT
        c.ID, ta.OtherID, tb.OtherID, ta.Score, tb.Score, ab.Score, t2a.Score, t2b.Score,
        CASE WHEN (t2a.Score IS NOT NULL AND ta.Score - t2a.Score <= @AmbiguityMargin)
                OR (t2b.Score IS NOT NULL AND tb.Score - t2b.Score <= @AmbiguityMargin)
             THEN 1 ELSE 0 END,
        CASE WHEN ta.OtherID IS NULL AND tb.OtherID IS NULL          THEN 'MANUAL'
             WHEN (t2a.Score IS NOT NULL AND ta.Score - t2a.Score <= @AmbiguityMargin)
               OR (t2b.Score IS NOT NULL AND tb.Score - t2b.Score <= @AmbiguityMargin)
                                                                     THEN 'REVIEW'
             WHEN ta.Verdict = 'AUTO' AND tb.Verdict = 'AUTO'        THEN 'AUTO'
             ELSE 'REVIEW' END,
        -- Each piece is '' or '; message'; STUFF drops the leading '; ', and
        -- returns NULL when nothing fired. (CONCAT_WS would be neater but is 2017+.)
        STUFF(CONCAT(
            CASE WHEN t2a.Score IS NOT NULL AND ta.Score - t2a.Score <= @AmbiguityMargin
                 THEN CONCAT(N'; Adopt card ambiguous (', ta.Score, N' vs ', t2a.Score, N')') ELSE N'' END,
            CASE WHEN t2b.Score IS NOT NULL AND tb.Score - t2b.Score <= @AmbiguityMargin
                 THEN CONCAT(N'; Birth card ambiguous (', tb.Score, N' vs ', t2b.Score, N')') ELSE N'' END,
            CASE WHEN ta.OtherID IS NOT NULL AND tb.OtherID IS NOT NULL AND ab.Score IS NULL
                 THEN N'; Adopt and Birth cards were never compared (no shared signal)' ELSE N'' END,
            CASE WHEN ab.Score IS NOT NULL AND ab.Score < 30
                 THEN N'; Adopt and Birth cards do not corroborate each other' ELSE N'' END,
            CASE WHEN ta.OtherID IS NULL THEN N'; No adoptive-parents card found' ELSE N'' END,
            CASE WHEN tb.OtherID IS NULL THEN N'; No birth-parents card found'    ELSE N'' END
        ), 1, 2, N'')
    FROM dbo.HSA_Adopt_AdoptionCardsNorm c
    LEFT JOIN Top1 ta  ON ta.ChildID  = c.ID AND ta.Type_A  = 'ADOPTIVE PARENTS'
    LEFT JOIN Top2 t2a ON t2a.ChildID = c.ID AND t2a.Type_A = 'ADOPTIVE PARENTS'
    LEFT JOIN Top1 tb  ON tb.ChildID  = c.ID AND tb.Type_A  = 'BIRTH PARENTS'
    LEFT JOIN Top2 t2b ON t2b.ChildID = c.ID AND t2b.Type_A = 'BIRTH PARENTS'
    LEFT JOIN HSA_Adopt_vPairTotals ab ON ab.Type_A = 'ADOPTIVE PARENTS' AND ab.Type_B = 'BIRTH PARENTS'
                            AND ab.ID_A = ta.OtherID AND ab.ID_B = tb.OtherID
    WHERE c.CardType = 'CHILD';

    -- Human decisions win over the algorithm, on every rebuild.
    UPDATE g
       SET g.AdoptCardID  = CASE WHEN o.Decision = 'CONFIRMED' THEN o.AdoptCardID ELSE NULL END,
           g.BirthCardID  = CASE WHEN o.Decision = 'CONFIRMED' THEN o.BirthCardID ELSE NULL END,
           g.Status       = CASE WHEN o.Decision = 'CONFIRMED' THEN 'CONFIRMED' ELSE 'MANUAL' END,
           g.Ambiguous    = 0,
           g.ReviewedBy   = o.ReviewedBy,
           g.ReviewedDate = o.ReviewedDate,
           g.Conflicts    = o.ReviewNote
    FROM dbo.HSA_Adopt_CaseGroups g
    JOIN dbo.HSA_Adopt_CaseReviewOverrides o ON o.ChildCardID = g.ChildCardID;

    COMMIT;

    SELECT Status, COUNT(*) AS Groups FROM dbo.HSA_Adopt_CaseGroups GROUP BY Status ORDER BY Status;
END;
GO

-- 6. REVIEW QUEUES ------------------------------------------------------
-- Every candidate above threshold for one child card, for the reviewer to choose from.
CREATE OR ALTER VIEW HSA_Adopt_vGroupCandidates AS
SELECT p.ID_B AS ChildCardID, p.Type_A AS CandidateType, p.ID_A AS CandidateCardID,
       p.Score, p.Verdict, p.HardEvidence,
       p.s_venA, p.s_dob, p.s_case, p.s_notescase,
       p.s_childlast, p.s_childfirst, p.s_birthparent, p.s_adoptparent
FROM HSA_Adopt_vPairTotals p
WHERE p.Type_B = 'CHILD' AND p.Score >= 45 AND p.Verdict <> 'NO';
GO

-- Groups needing a human look
-- SELECT * FROM dbo.HSA_Adopt_CaseGroups WHERE Status IN ('REVIEW','MANUAL') ORDER BY Ambiguous DESC, Status, ScoreChildAdopt DESC;

-- Same ADOPT or BIRTH card claimed by more than one child (duplicate-link check).
-- Legitimate for sibling adoptions; a red flag otherwise.
-- SELECT AdoptCardID, COUNT(*) n FROM dbo.HSA_Adopt_CaseGroups WHERE AdoptCardID IS NOT NULL GROUP BY AdoptCardID HAVING COUNT(*) > 1;
-- SELECT BirthCardID, COUNT(*) n FROM dbo.HSA_Adopt_CaseGroups WHERE BirthCardID IS NOT NULL GROUP BY BirthCardID HAVING COUNT(*) > 1;

-- Orphan ADOPT/BIRTH cards never linked to any child
-- SELECT n.* FROM dbo.HSA_Adopt_AdoptionCardsNorm n
-- WHERE n.CardType IN ('ADOPTIVE PARENTS','BIRTH PARENTS')
--   AND NOT EXISTS (SELECT 1 FROM dbo.HSA_Adopt_CaseGroups g WHERE n.ID IN (g.AdoptCardID, g.BirthCardID));

-- 7. FINAL OUTPUT: one readable row per triangulated case ---------------
CREATE OR ALTER VIEW HSA_Adopt_vTriangulatedCases AS
SELECT g.GroupID, g.Status, g.Ambiguous, g.ScoreChildAdopt, g.ScoreChildBirth,
       g.ScoreAdoptBirth, g.Conflicts, g.ReviewedBy, g.ReviewedDate,
       ch.ID AS Child_ID,
       LTRIM(RTRIM(CONCAT(ch.Child_BirthFirst, N' ', ch.Child_BirthLast))) AS Child_BirthName,
       LTRIM(RTRIM(CONCAT(ch.Child_AdoptFirst, N' ', ch.Child_AdoptLast))) AS Child_AdoptName,
       ch.Child_DOB, ch.Case_Number AS Child_CaseNumber, ch.Filepath AS Child_Filepath,
       ad.ID AS Adopt_ID, ad.Case_Number AS Adopt_CaseNumber, ad.A_Number AS Adopt_ANumber,
       ad.Filepath AS Adopt_Filepath, bi.Filepath AS Birth_Filepath,
       LTRIM(RTRIM(CONCAT(ad.AdoptParent_1_First, N' ', ad.AdoptParent_1_Last))) AS AdoptParent1,
       LTRIM(RTRIM(CONCAT(ad.AdoptParent_2_First, N' ', ad.AdoptParent_2_Last))) AS AdoptParent2,
       ad.FinalDate_FinalDecree, ad.CloseDate,
       bi.ID AS Birth_ID, bi.Case_Number AS Birth_CaseNumber, bi.VEN_Number AS Birth_VEN,
       LTRIM(RTRIM(CONCAT(bi.BirthParent_1_First, N' ', bi.BirthParent_1_Last))) AS BirthParent1,
       LTRIM(RTRIM(CONCAT(bi.BirthParent_2_First, N' ', bi.BirthParent_2_Last))) AS BirthParent2
FROM dbo.HSA_Adopt_CaseGroups g
JOIN dbo.HSA_Adopt_AdoptionCards ch      ON ch.ID = g.ChildCardID
LEFT JOIN dbo.HSA_Adopt_AdoptionCards ad ON ad.ID = g.AdoptCardID
LEFT JOIN dbo.HSA_Adopt_AdoptionCards bi ON bi.ID = g.BirthCardID;
GO

-- 8. AUDIT LOG ----------------------------------------------------------
-- Written before the result set is produced, so a cancelled query is still logged.
IF OBJECT_ID('dbo.HSA_Adopt_SearchLog', 'U') IS NULL
CREATE TABLE dbo.HSA_Adopt_SearchLog (
    SearchID      BIGINT IDENTITY(1,1) PRIMARY KEY,
    SearchedAtUtc DATETIME2(0)  NOT NULL CONSTRAINT DF_HSA_Adopt_SL_At    DEFAULT SYSUTCDATETIME(),
    LoginName     SYSNAME       NOT NULL CONSTRAINT DF_HSA_Adopt_SL_Login DEFAULT SUSER_SNAME(),
    AppUser       NVARCHAR(200) NULL,      -- end user, when the front end supplies it
    HostName      NVARCHAR(200) NULL CONSTRAINT DF_HSA_Adopt_SL_Host DEFAULT HOST_NAME(),
    AppName       NVARCHAR(200) NULL CONSTRAINT DF_HSA_Adopt_SL_App  DEFAULT APP_NAME(),
    ClientIP      NVARCHAR(48)  NULL,
    Reason        NVARCHAR(200) NULL,      -- records-request reference
    P_LastName    NVARCHAR(200) NULL,
    P_FirstName   NVARCHAR(200) NULL,
    P_CaseNumber  NVARCHAR(200) NULL,
    P_VEN_or_A    NVARCHAR(200) NULL,
    P_DOB         DATE          NULL,
    P_DOBYear     INT           NULL,
    P_AnyText     NVARCHAR(200) NULL,
    P_Fuzzy       BIT           NULL,
    P_DOBFuzzy    BIT           NULL,
    P_NameRole    NVARCHAR(20)  NULL,
    P_Names       NVARCHAR(400) NULL,
    P_CloseDate   DATE          NULL,
    P_FinalDate   DATE          NULL,
    P_AnyDate     DATE          NULL,
    P_Anywhere    NVARCHAR(400) NULL,
    P_CardType    NVARCHAR(20)  NULL,
    RowsReturned  INT           NULL
);
-- If the table already exists from an earlier run, add the column instead:
-- IF COL_LENGTH('dbo.HSA_Adopt_SearchLog','P_DOBFuzzy') IS NULL ALTER TABLE dbo.HSA_Adopt_SearchLog ADD P_DOBFuzzy BIT NULL;
-- IF COL_LENGTH('dbo.HSA_Adopt_SearchLog','P_NameRole') IS NULL ALTER TABLE dbo.HSA_Adopt_SearchLog ADD P_NameRole NVARCHAR(20) NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_HSA_Adopt_SL_At' AND object_id = OBJECT_ID('dbo.HSA_Adopt_SearchLog'))
    CREATE INDEX IX_HSA_Adopt_SL_At   ON dbo.HSA_Adopt_SearchLog(SearchedAtUtc);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_HSA_Adopt_SL_User' AND object_id = OBJECT_ID('dbo.HSA_Adopt_SearchLog'))
    CREATE INDEX IX_HSA_Adopt_SL_User ON dbo.HSA_Adopt_SearchLog(LoginName, SearchedAtUtc);
GO

-- 9. SEARCH: find cards + their full case from any fragment --------------
-- All search parameters optional. Name searches hit EVERY person on the card;
-- numbers match on digits only. Returns direct hits AND the rest of their case.
CREATE OR ALTER PROCEDURE dbo.HSA_Adopt_usp_SearchCards
    @LastName   NVARCHAR(200) = NULL,   -- LIKE + SOUNDEX, on whichever names @NameRole allows
    @FirstName  NVARCHAR(200) = NULL,
    @Names      NVARCHAR(400) = NULL,   -- name terms separated by '|'; the CASE must carry every
                                        -- one somewhere among the names @NameRole allows
    @NameRole   NVARCHAR(20)  = NULL,   -- WHOSE name the three above are:
                                        --   NULL          anyone on the card (default)
                                        --   CHILD_BIRTH   the child's birth name
                                        --   CHILD_ADOPT   the child's adopted name
                                        --   BIRTH_PARENT  a birth parent
                                        --   ADOPT_PARENT  an adoptive parent
    @CardType   NVARCHAR(20)  = NULL,   -- only cards of this type may SATISFY the search:
                                        -- NULL = any | CHILD | BIRTH PARENTS | ADOPTIVE PARENTS.
                                        -- The rest of the case is still returned alongside.
    @CaseNumber NVARCHAR(200) = NULL,   -- any format; digits compared, Notes included
    @VEN_or_A   NVARCHAR(200) = NULL,   -- searches both VEN# and A#
    @DOB        DATE          = NULL,
    @DOBYear    INT           = NULL,   -- when only the birth year is known
    @CloseDate  DATE          = NULL,
    @FinalDate  DATE          = NULL,   -- final decree
    @AnyDate    DATE          = NULL,   -- matches ANY of the three date columns
    @AnyText    NVARCHAR(200) = NULL,   -- free text across Notes + all names
    @Anywhere   NVARCHAR(400) = NULL,   -- terms separated by '|', each matched against
                                        -- EVERYTHING: names, notes, numbers by their digits,
                                        -- all three dates, a bare year against any date's year
    @Fuzzy      BIT           = 1,      -- 0 = exact/LIKE only, 1 = also SOUNDEX on surnames
    @DOBFuzzy   BIT           = 0,      -- 1 = a date may have one wrong part (yr/mo/day)
    @AppUser    NVARCHAR(200) = NULL,   -- end user, from the front end
    @Reason     NVARCHAR(200) = NULL    -- request reference, for the audit trail
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @LN    NVARCHAR(200) = dbo.HSA_Adopt_fnNormName(@LastName),
            @FN    NVARCHAR(200) = dbo.HSA_Adopt_fnNormName(@FirstName),
            @LN_SX CHAR(4)       = SOUNDEX(dbo.HSA_Adopt_fnNormName(@LastName)),
            @CaseD NVARCHAR(100) = dbo.HSA_Adopt_fnDigitsOnly(@CaseNumber),
            @NumD  NVARCHAR(100) = dbo.HSA_Adopt_fnDigitsOnly(@VEN_or_A),
            @Txt   NVARCHAR(200) = NULLIF(LTRIM(RTRIM(@AnyText)), N''),
            @IP    NVARCHAR(48)  = NULL,
            @SearchID BIGINT, @Rows INT;

    SET @CardType = UPPER(LTRIM(RTRIM(@CardType)));
    IF @CardType NOT IN (N'CHILD', N'BIRTH PARENTS', N'ADOPTIVE PARENTS') SET @CardType = NULL;

    -- Which name slots a name search may hit. An unrecognised role means "anyone".
    SET @NameRole = UPPER(LTRIM(RTRIM(@NameRole)));
    IF @NameRole NOT IN (N'CHILD_BIRTH', N'CHILD_ADOPT', N'BIRTH_PARENT', N'ADOPT_PARENT')
        SET @NameRole = NULL;
    DECLARE @rCB BIT = CASE WHEN @NameRole IS NULL OR @NameRole = N'CHILD_BIRTH'  THEN 1 ELSE 0 END,
            @rCA BIT = CASE WHEN @NameRole IS NULL OR @NameRole = N'CHILD_ADOPT'  THEN 1 ELSE 0 END,
            @rBP BIT = CASE WHEN @NameRole IS NULL OR @NameRole = N'BIRTH_PARENT' THEN 1 ELSE 0 END,
            @rAP BIT = CASE WHEN @NameRole IS NULL OR @NameRole = N'ADOPT_PARENT' THEN 1 ELSE 0 END;

    -- Multi-term names: split, normalise each once, drop empties.
    DECLARE @T TABLE (term NVARCHAR(200) NOT NULL);
    IF @Names IS NOT NULL
        INSERT INTO @T
        SELECT DISTINCT t.norm
        FROM (SELECT dbo.HSA_Adopt_fnNormName(value) AS norm FROM STRING_SPLIT(@Names, '|')) t
        WHERE t.norm IS NOT NULL;
    DECLARE @nTerms INT = (SELECT COUNT(*) FROM @T);
    IF @nTerms = 0 SET @Names = NULL;          -- ',,,' must not count as a criterion

    -- "Anywhere" terms: each prepared every way it might match.
    DECLARE @A TABLE (term NVARCHAR(200) NOT NULL, norm NVARCHAR(200) NULL,
                      digits NVARCHAR(100) NULL, dt DATE NULL, yr INT NULL);
    IF @Anywhere IS NOT NULL
        INSERT INTO @A (term, norm, digits, dt, yr)
        SELECT DISTINCT t.term, dbo.HSA_Adopt_fnNormName(t.term),
               CASE WHEN LEN(dbo.HSA_Adopt_fnDigitsOnly(t.term)) >= 4
                    THEN dbo.HSA_Adopt_fnDigitsOnly(t.term) END,
               CASE WHEN t.term LIKE N'[12][0-9][0-9][0-9]' THEN NULL   -- a bare year is not a date
                    ELSE COALESCE(TRY_CONVERT(DATE, t.term, 101),        -- m/d/yyyy
                                  TRY_CONVERT(DATE, t.term, 120)) END,   -- yyyy-mm-dd
               CASE WHEN t.term LIKE N'[12][0-9][0-9][0-9]' THEN CAST(t.term AS INT) END
        FROM (SELECT LTRIM(RTRIM(value)) AS term FROM STRING_SPLIT(@Anywhere, '|')) t
        WHERE t.term <> N'';
    DECLARE @nAny INT = (SELECT COUNT(*) FROM @A);
    IF @nAny = 0 SET @Anywhere = NULL;

    IF COALESCE(@LN, @FN, @Names, @Anywhere, @CaseD, @NumD,
                CONVERT(NVARCHAR(8), @DOB, 112), CONVERT(NVARCHAR(8), @CloseDate, 112),
                CONVERT(NVARCHAR(8), @FinalDate, 112), CONVERT(NVARCHAR(8), @AnyDate, 112),
                CONVERT(NVARCHAR(4), @DOBYear), @Txt) IS NULL
    BEGIN
        RAISERROR('Supply at least one search parameter.', 16, 1);
        RETURN;
    END

    BEGIN TRY
        SELECT @IP = CONVERT(NVARCHAR(48), client_net_address)
        FROM sys.dm_exec_connections WHERE session_id = @@SPID;
    END TRY
    BEGIN CATCH SET @IP = NULL; END CATCH   -- caller may lack VIEW SERVER STATE

    INSERT INTO dbo.HSA_Adopt_SearchLog
        (AppUser, ClientIP, Reason, P_LastName, P_FirstName, P_CaseNumber, P_VEN_or_A,
         P_DOB, P_DOBYear, P_AnyText, P_Fuzzy, P_DOBFuzzy, P_NameRole, P_Names,
         P_CloseDate, P_FinalDate, P_AnyDate, P_Anywhere, P_CardType)
    VALUES (@AppUser, @IP, @Reason, @LastName, @FirstName, @CaseNumber, @VEN_or_A,
            @DOB, @DOBYear, @AnyText, @Fuzzy, @DOBFuzzy, @NameRole, @Names,
            @CloseDate, @FinalDate, @AnyDate, @Anywhere, @CardType);
    SET @SearchID = SCOPE_IDENTITY();

    /* -----------------------------------------------------------------
       Matching happens at the CASE level, not the card level.
       A case (its three cards together) qualifies when every term is found
       on at least one of its cards and every other criterion is satisfied
       by at least one of its cards -- so "adoptive parent Cross, birth
       mother Ward, born 1959" works even though those facts sit on three
       different cards. An unlinked card is a case of one.
       ----------------------------------------------------------------- */
    IF OBJECT_ID('tempdb..#cf') IS NOT NULL DROP TABLE #cf;
    IF OBJECT_ID('tempdb..#nm') IS NOT NULL DROP TABLE #nm;
    IF OBJECT_ID('tempdb..#am') IS NOT NULL DROP TABLE #am;

    SELECT n.ID, n.CardType,
           ck = COALESCE(g.GroupID, -n.ID),        -- case key; a lone card is its own case
           g.GroupID, g.Status AS GroupStatus, g.Ambiguous, g.Conflicts,
           m.ln_cb, m.ln_ca, m.ln_bp, m.ln_ap, m.fn_cb, m.fn_ca, m.fn_bp, m.fn_ap,
           ln_ok    = CASE WHEN m.ln_cb + m.ln_ca + m.ln_bp + m.ln_ap > 0 THEN 1 ELSE 0 END,
           fn_ok    = CASE WHEN m.fn_cb + m.fn_ca + m.fn_bp + m.fn_ap > 0 THEN 1 ELSE 0 END,
           case_ok  = CASE WHEN @CaseD IS NOT NULL AND n.CaseDigits  LIKE '%'+@CaseD+'%' THEN 1 ELSE 0 END,
           notes_ok = CASE WHEN @CaseD IS NOT NULL AND n.NotesDigits LIKE '%'+@CaseD+'%' THEN 1 ELSE 0 END,
           num_ok   = CASE WHEN @NumD IS NOT NULL AND (n.VENDigits = @NumD OR n.ADigits = @NumD) THEN 1 ELSE 0 END,
           dob_exact  = CASE WHEN @DOB IS NOT NULL AND n.Child_DOB = @DOB THEN 1 ELSE 0 END,
           dob_near   = CASE WHEN @DOB IS NOT NULL AND @DOBFuzzy = 1 AND n.Child_DOB IS NOT NULL
                              AND n.Child_DOB <> @DOB AND d.dob2 >= 2 THEN 1 ELSE 0 END,
           year_ok    = CASE WHEN @DOBYear IS NOT NULL AND YEAR(n.Child_DOB) = @DOBYear THEN 1 ELSE 0 END,
           close_ok   = CASE WHEN @CloseDate IS NOT NULL AND c.CloseDate = @CloseDate THEN 1 ELSE 0 END,
           final_ok   = CASE WHEN @FinalDate IS NOT NULL AND c.FinalDate_FinalDecree = @FinalDate THEN 1 ELSE 0 END,
           any_exact  = CASE WHEN @AnyDate IS NOT NULL
                              AND @AnyDate IN (n.Child_DOB, c.CloseDate, c.FinalDate_FinalDecree) THEN 1 ELSE 0 END,
           any_near   = CASE WHEN @AnyDate IS NOT NULL AND @DOBFuzzy = 1
                              AND @AnyDate NOT IN (ISNULL(n.Child_DOB,'19000101'), ISNULL(c.CloseDate,'19000101'),
                                                   ISNULL(c.FinalDate_FinalDecree,'19000101'))
                              AND (d.any_dob >= 2 OR d.any_close >= 2 OR d.any_final >= 2) THEN 1 ELSE 0 END,
           txt_ok   = CASE WHEN @Txt IS NOT NULL AND (c.Notes LIKE '%'+@Txt+'%'
                                                   OR n.AllNames LIKE '%'+@Txt+'%') THEN 1 ELSE 0 END,
           h.hay,
           -- for "anywhere" matching
           NotesU  = UPPER(c.Notes),
           RawNums = UPPER(CONCAT(c.Case_Number, N' ', c.VEN_Number, N' ', c.A_Number)),
           n.CaseDigits, n.NotesDigits, n.VENDigits, n.ADigits,
           n.Child_DOB, c.CloseDate, FinalDate = c.FinalDate_FinalDecree
    INTO #cf
    FROM dbo.HSA_Adopt_AdoptionCardsNorm n
    JOIN dbo.HSA_Adopt_AdoptionCards c ON c.ID = n.ID
    -- A card in two groups deliberately appears under both: that is a visible
    -- symptom of a duplicate claim, and hiding it would keep a bad link invisible.
    LEFT JOIN dbo.HSA_Adopt_CaseGroups g ON n.ID IN (g.ChildCardID, g.AdoptCardID, g.BirthCardID)
    -- how many of year/month/day agree, for the one-part-wrong date rule
    CROSS APPLY (SELECT
        dob2      = CASE WHEN YEAR(n.Child_DOB)=YEAR(@DOB) THEN 1 ELSE 0 END + CASE WHEN MONTH(n.Child_DOB)=MONTH(@DOB) THEN 1 ELSE 0 END + CASE WHEN DAY(n.Child_DOB)=DAY(@DOB) THEN 1 ELSE 0 END,
        any_dob   = CASE WHEN YEAR(n.Child_DOB)=YEAR(@AnyDate) THEN 1 ELSE 0 END + CASE WHEN MONTH(n.Child_DOB)=MONTH(@AnyDate) THEN 1 ELSE 0 END + CASE WHEN DAY(n.Child_DOB)=DAY(@AnyDate) THEN 1 ELSE 0 END,
        any_close = CASE WHEN YEAR(c.CloseDate)=YEAR(@AnyDate) THEN 1 ELSE 0 END + CASE WHEN MONTH(c.CloseDate)=MONTH(@AnyDate) THEN 1 ELSE 0 END + CASE WHEN DAY(c.CloseDate)=DAY(@AnyDate) THEN 1 ELSE 0 END,
        any_final = CASE WHEN YEAR(c.FinalDate_FinalDecree)=YEAR(@AnyDate) THEN 1 ELSE 0 END + CASE WHEN MONTH(c.FinalDate_FinalDecree)=MONTH(@AnyDate) THEN 1 ELSE 0 END + CASE WHEN DAY(c.FinalDate_FinalDecree)=DAY(@AnyDate) THEN 1 ELSE 0 END
    ) d
    -- One place that decides which name slots matched, used by both the
    -- qualification and the MatchedOn text so the two can never disagree.
    CROSS APPLY (SELECT
        ln_cb = CASE WHEN @LN IS NULL OR @rCB = 0                   THEN 0
                     WHEN n.CBL LIKE '%'+@LN+'%'                    THEN 2
                     WHEN @Fuzzy = 1 AND n.CBL_SX = @LN_SX          THEN 1 ELSE 0 END,
        ln_ca = CASE WHEN @LN IS NULL OR @rCA = 0                   THEN 0
                     WHEN n.CAL LIKE '%'+@LN+'%'                    THEN 2
                     WHEN @Fuzzy = 1 AND n.CAL_SX = @LN_SX          THEN 1 ELSE 0 END,
        ln_bp = CASE WHEN @LN IS NULL OR @rBP = 0                   THEN 0
                     WHEN n.BP1_L LIKE '%'+@LN+'%'
                       OR n.BP2_L LIKE '%'+@LN+'%'                  THEN 2
                     WHEN @Fuzzy = 1 AND @LN_SX IN (n.BP1_SX, n.BP2_SX) THEN 1 ELSE 0 END,
        ln_ap = CASE WHEN @LN IS NULL OR @rAP = 0                   THEN 0
                     WHEN n.AP1_L LIKE '%'+@LN+'%'
                       OR n.AP2_L LIKE '%'+@LN+'%'                  THEN 2
                     WHEN @Fuzzy = 1 AND @LN_SX IN (n.AP1_SX, n.AP2_SX) THEN 1 ELSE 0 END,
        fn_cb = CASE WHEN @FN IS NOT NULL AND @rCB = 1 AND n.CBF LIKE '%'+@FN+'%' THEN 1 ELSE 0 END,
        fn_ca = CASE WHEN @FN IS NOT NULL AND @rCA = 1 AND n.CAF LIKE '%'+@FN+'%' THEN 1 ELSE 0 END,
        fn_bp = CASE WHEN @FN IS NOT NULL AND @rBP = 1
                      AND (n.BP1_F LIKE '%'+@FN+'%' OR n.BP2_F LIKE '%'+@FN+'%') THEN 1 ELSE 0 END,
        fn_ap = CASE WHEN @FN IS NOT NULL AND @rAP = 1
                      AND (n.AP1_F LIKE '%'+@FN+'%' OR n.AP2_F LIKE '%'+@FN+'%') THEN 1 ELSE 0 END
    ) m
    -- Every normalised name the role allows, as one string, for term matching.
    -- CBF/CAF rather than *_Real so 'BABY BOY' stays searchable.
    CROSS APPLY (SELECT hay = CASE @NameRole
        WHEN N'CHILD_BIRTH'  THEN CONCAT(n.CBF, N' ', n.CBL)
        WHEN N'CHILD_ADOPT'  THEN CONCAT(n.CAF, N' ', n.CAL)
        WHEN N'BIRTH_PARENT' THEN CONCAT(n.BP1_F, N' ', n.BP1_L, N' ', n.BP2_F, N' ', n.BP2_L)
        WHEN N'ADOPT_PARENT' THEN CONCAT(n.AP1_F, N' ', n.AP1_L, N' ', n.AP2_F, N' ', n.AP2_L)
        ELSE CONCAT(n.CBF, N' ', n.CBL, N' ', n.CAF, N' ', n.CAL, N' ',
                    n.BP1_F, N' ', n.BP1_L, N' ', n.BP2_F, N' ', n.BP2_L, N' ',
                    n.AP1_F, N' ', n.AP1_L, N' ', n.AP2_F, N' ', n.AP2_L) END) h;

    CREATE INDEX ix_cf ON #cf(ck);

    -- Card-type filter: cards of any other type stay in the case (so the whole
    -- case is still returned) but lose every way of satisfying the search.
    IF @CardType IS NOT NULL
        UPDATE #cf SET
            ln_cb = 0, ln_ca = 0, ln_bp = 0, ln_ap = 0, fn_cb = 0, fn_ca = 0, fn_bp = 0, fn_ap = 0,
            ln_ok = 0, fn_ok = 0, case_ok = 0, notes_ok = 0, num_ok = 0,
            dob_exact = 0, dob_near = 0, year_ok = 0, close_ok = 0, final_ok = 0,
            any_exact = 0, any_near = 0, txt_ok = 0,
            hay = N'', NotesU = NULL, RawNums = NULL,
            CaseDigits = NULL, NotesDigits = NULL, VENDigits = NULL, ADigits = NULL,
            Child_DOB = NULL, CloseDate = NULL, FinalDate = NULL
        WHERE CardType <> @CardType;

    -- Which cards carry which name terms, and which carry which "anywhere" terms.
    -- Written once here; the qualification and the MatchedOn text both read these.
    SELECT f.ID, f.ck, t.term INTO #nm
    FROM #cf f CROSS JOIN @T t
    WHERE f.hay LIKE N'%' + t.term + N'%';

    SELECT f.ID, f.ck, a.term INTO #am
    FROM #cf f CROSS JOIN @A a
    WHERE (a.norm IS NOT NULL AND (f.hay LIKE N'%' + a.norm + N'%'
                                OR f.NotesU LIKE N'%' + UPPER(a.term) + N'%'
                                OR f.RawNums LIKE N'%' + UPPER(a.term) + N'%'))
       OR (a.digits IS NOT NULL AND (f.CaseDigits  LIKE N'%' + a.digits + N'%'
                                  OR f.NotesDigits LIKE N'%' + a.digits + N'%'
                                  OR f.VENDigits = a.digits OR f.ADigits = a.digits))
       OR (a.dt IS NOT NULL AND a.dt IN (f.Child_DOB, f.CloseDate, f.FinalDate))
       OR (a.yr IS NOT NULL AND a.yr IN (YEAR(f.Child_DOB), YEAR(f.CloseDate), YEAR(f.FinalDate)));

    ;WITH CaseOK AS (
        SELECT f.ck
        FROM #cf f
        GROUP BY f.ck
        HAVING (@LN        IS NULL OR MAX(f.ln_ok)    = 1)
           AND (@FN        IS NULL OR MAX(f.fn_ok)    = 1)
           AND (@CaseD     IS NULL OR MAX(f.case_ok)  = 1 OR MAX(f.notes_ok) = 1)
           AND (@NumD      IS NULL OR MAX(f.num_ok)   = 1)
           AND (@DOB       IS NULL OR MAX(f.dob_exact) = 1 OR MAX(f.dob_near) = 1)
           AND (@DOBYear   IS NULL OR MAX(f.year_ok)  = 1)
           AND (@CloseDate IS NULL OR MAX(f.close_ok) = 1)
           AND (@FinalDate IS NULL OR MAX(f.final_ok) = 1)
           AND (@AnyDate   IS NULL OR MAX(f.any_exact) = 1 OR MAX(f.any_near) = 1)
           AND (@Txt       IS NULL OR MAX(f.txt_ok)   = 1)
           -- every term must be found on SOME card of this case
           AND (@nTerms = 0 OR (SELECT COUNT(DISTINCT x.term) FROM #nm x WHERE x.ck = f.ck) = @nTerms)
           AND (@nAny   = 0 OR (SELECT COUNT(DISTINCT x.term) FROM #am x WHERE x.ck = f.ck) = @nAny)
    )
    SELECT
        ISNULL(f.GroupID, 0)              AS GroupID,
        ISNULL(f.GroupStatus, 'UNLINKED') AS GroupStatus,
        f.Ambiguous, f.Conflicts,
        c.ID, c.CardType,
        CASE WHEN f.ln_ok + f.fn_ok + f.case_ok + f.notes_ok + f.num_ok + f.dob_exact + f.dob_near
                + f.year_ok + f.close_ok + f.final_ok + f.any_exact + f.any_near + f.txt_ok > 0
               OR EXISTS (SELECT 1 FROM #nm x WHERE x.ID = f.ID AND x.ck = f.ck)
               OR EXISTS (SELECT 1 FROM #am x WHERE x.ID = f.ID AND x.ck = f.ck)
             THEN 'DIRECT' ELSE 'via case' END AS HitType,
        NULLIF(STUFF(
              CASE f.ln_cb WHEN 2 THEN ', Birth surname'
                           WHEN 1 THEN ', Birth surname (sounds like)' ELSE '' END
            + CASE f.ln_ca WHEN 2 THEN ', Adopted surname'
                           WHEN 1 THEN ', Adopted surname (sounds like)' ELSE '' END
            + CASE f.ln_bp WHEN 2 THEN ', Birth parent surname'
                           WHEN 1 THEN ', Birth parent surname (sounds like)' ELSE '' END
            + CASE f.ln_ap WHEN 2 THEN ', Adoptive parent surname'
                           WHEN 1 THEN ', Adoptive parent surname (sounds like)' ELSE '' END
            + CASE WHEN f.fn_cb = 1 THEN ', Birth first name'           ELSE '' END
            + CASE WHEN f.fn_ca = 1 THEN ', Adopted first name'         ELSE '' END
            + CASE WHEN f.fn_bp = 1 THEN ', Birth parent first name'    ELSE '' END
            + CASE WHEN f.fn_ap = 1 THEN ', Adoptive parent first name' ELSE '' END
            + ISNULL((SELECT ', Name: ' + x.term FROM #nm x WHERE x.ID = f.ID AND x.ck = f.ck
                      ORDER BY x.term FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)'), '')
            + ISNULL((SELECT ', Found: ' + x.term FROM #am x WHERE x.ID = f.ID AND x.ck = f.ck
                      ORDER BY x.term FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)'), '')
            + CASE WHEN f.case_ok  = 1 THEN ', Case number'     ELSE '' END
            + CASE WHEN f.notes_ok = 1 THEN ', Number in Notes' ELSE '' END
            + CASE WHEN f.num_ok   = 1 THEN ', VEN/A#'          ELSE '' END
            + CASE WHEN f.dob_exact = 1 THEN ', DOB'
                   WHEN f.dob_near  = 1 THEN ', DOB (one part differs)' ELSE '' END
            + CASE WHEN f.year_ok  = 1 THEN ', DOB year'        ELSE '' END
            + CASE WHEN f.close_ok = 1 THEN ', Closed date'     ELSE '' END
            + CASE WHEN f.final_ok = 1 THEN ', Final decree date' ELSE '' END
            + CASE WHEN f.any_exact = 1 THEN ', Date'
                   WHEN f.any_near  = 1 THEN ', Date (one part differs)' ELSE '' END
            + CASE WHEN f.txt_ok   = 1 THEN ', Text'            ELSE '' END
            , 1, 2, ''), '') AS MatchedOn,
        c.Child_BirthFirst, c.Child_BirthLast, c.Child_AdoptFirst, c.Child_AdoptLast, c.Child_DOB,
        c.BirthParent_1_First, c.BirthParent_1_Last, c.BirthParent_2_First, c.BirthParent_2_Last,
        c.AdoptParent_1_First, c.AdoptParent_1_Last, c.AdoptParent_2_First, c.AdoptParent_2_Last,
        c.Case_Number, c.VEN_Number, c.A_Number, c.FinalDate_FinalDecree, c.CloseDate,
        c.Notes, c.Filepath
    FROM #cf f
    JOIN dbo.HSA_Adopt_AdoptionCards c ON c.ID = f.ID
    WHERE f.ck IN (SELECT ck FROM CaseOK)
    ORDER BY GroupID,
             CASE c.CardType WHEN 'CHILD' THEN 1 WHEN 'BIRTH PARENTS' THEN 2 ELSE 3 END;

    SET @Rows = @@ROWCOUNT;
    UPDATE dbo.HSA_Adopt_SearchLog SET RowsReturned = @Rows WHERE SearchID = @SearchID;
    DROP TABLE #am; DROP TABLE #nm; DROP TABLE #cf;
END;
GO

-- 9b. BROWSE: one sorted page of cards at a time, for the page's Browse tab -
-- Staff cannot read the tables directly, so scrolling needs its own proc.
-- Every page viewed is written to the search log ('[browse] ...' in P_AnyText).
IF OBJECT_ID('dbo.HSA_Adopt_usp_BrowseCards', 'P') IS NOT NULL
    DROP PROCEDURE dbo.HSA_Adopt_usp_BrowseCards;
GO

CREATE PROCEDURE dbo.HSA_Adopt_usp_BrowseCards
    @CardType     NVARCHAR(20)  = NULL,   -- CHILD / BIRTH PARENTS / ADOPTIVE PARENTS
    @GroupStatus  NVARCHAR(12)  = NULL,   -- AUTO / REVIEW / MANUAL / CONFIRMED / UNLINKED
    @SortBy       NVARCHAR(40)  = 'ID',
    @SortDir      NVARCHAR(4)   = 'ASC',
    @Page         INT           = 1,
    @PageSize     INT           = 100,
    @AppUser      NVARCHAR(200) = NULL,
    @Reason       NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @CardType    = NULLIF(UPPER(LTRIM(RTRIM(@CardType))), N'');
    SET @GroupStatus = NULLIF(UPPER(LTRIM(RTRIM(@GroupStatus))), N'');
    SET @SortDir     = CASE WHEN UPPER(@SortDir) = N'DESC' THEN N'DESC' ELSE N'ASC' END;
    IF @Page < 1 SET @Page = 1;
    IF @PageSize < 1 OR @PageSize > 500 SET @PageSize = 100;

    -- Only these columns can be sorted on. Anything else falls back to ID.
    IF @SortBy NOT IN (N'ID', N'CardType', N'Child_BirthLast', N'Child_BirthFirst',
                       N'Child_AdoptLast', N'Child_AdoptFirst', N'Child_DOB',
                       N'BirthParent_1_Last', N'BirthParent_2_Last',
                       N'AdoptParent_1_Last', N'AdoptParent_2_Last',
                       N'Case_Number', N'VEN_Number', N'A_Number',
                       N'FinalDate_FinalDecree', N'CloseDate', N'GroupID', N'GroupStatus')
        SET @SortBy = N'ID';

    DECLARE @IP NVARCHAR(48);
    BEGIN TRY
        SELECT @IP = CONVERT(NVARCHAR(48), client_net_address)
        FROM sys.dm_exec_connections WHERE session_id = @@SPID;
    END TRY
    BEGIN CATCH SET @IP = NULL; END CATCH

    DECLARE @SearchID BIGINT;
    INSERT INTO dbo.HSA_Adopt_SearchLog (AppUser, ClientIP, Reason, P_AnyText, P_CardType)
    VALUES (@AppUser, @IP, @Reason,
            N'[browse] ' + ISNULL(@GroupStatus, N'all') + N' sort=' + @SortBy + N' ' + @SortDir
            + N' page=' + CONVERT(NVARCHAR(10), @Page) + N' size=' + CONVERT(NVARCHAR(10), @PageSize),
            @CardType);
    SET @SearchID = SCOPE_IDENTITY();

    ;WITH src AS (
        SELECT c.*,
               g.GroupID, GroupStatus = ISNULL(g.Status, N'UNLINKED'), g.Ambiguous, g.Conflicts,
               -- one key per data type; the ORDER BY below picks the right one
               kText = CASE @SortBy
                           WHEN N'CardType'           THEN c.CardType
                           WHEN N'Child_BirthLast'    THEN c.Child_BirthLast
                           WHEN N'Child_BirthFirst'   THEN c.Child_BirthFirst
                           WHEN N'Child_AdoptLast'    THEN c.Child_AdoptLast
                           WHEN N'Child_AdoptFirst'   THEN c.Child_AdoptFirst
                           WHEN N'BirthParent_1_Last' THEN c.BirthParent_1_Last
                           WHEN N'BirthParent_2_Last' THEN c.BirthParent_2_Last
                           WHEN N'AdoptParent_1_Last' THEN c.AdoptParent_1_Last
                           WHEN N'AdoptParent_2_Last' THEN c.AdoptParent_2_Last
                           WHEN N'Case_Number'        THEN c.Case_Number
                           WHEN N'VEN_Number'         THEN c.VEN_Number
                           WHEN N'A_Number'           THEN c.A_Number
                           WHEN N'GroupStatus'        THEN ISNULL(g.Status, N'UNLINKED')
                       END,
               kNum  = CASE @SortBy WHEN N'ID' THEN c.ID WHEN N'GroupID' THEN g.GroupID END,
               kDate = CASE @SortBy
                           WHEN N'Child_DOB'             THEN c.Child_DOB
                           WHEN N'FinalDate_FinalDecree' THEN c.FinalDate_FinalDecree
                           WHEN N'CloseDate'             THEN c.CloseDate
                       END
        FROM dbo.HSA_Adopt_AdoptionCards c
        LEFT JOIN dbo.HSA_Adopt_CaseGroups g ON c.ID IN (g.ChildCardID, g.AdoptCardID, g.BirthCardID)
        WHERE (@CardType    IS NULL OR UPPER(c.CardType) = @CardType)
          AND (@GroupStatus IS NULL OR ISNULL(g.Status, N'UNLINKED') = @GroupStatus)
    )
    SELECT TotalRows = COUNT(*) OVER (),
           ID, CardType, GroupID, GroupStatus, Ambiguous, Conflicts,
           Child_BirthFirst, Child_BirthLast, Child_AdoptFirst, Child_AdoptLast, Child_DOB,
           BirthParent_1_First, BirthParent_1_Last, BirthParent_2_First, BirthParent_2_Last,
           AdoptParent_1_First, AdoptParent_1_Last, AdoptParent_2_First, AdoptParent_2_Last,
           Case_Number, VEN_Number, A_Number, FinalDate_FinalDecree, CloseDate, Notes, Filepath
    FROM src
    ORDER BY
        -- NULLs (blank cells) always sink to the bottom, whichever direction
        CASE WHEN COALESCE(kText, CONVERT(NVARCHAR(30), kNum), CONVERT(NVARCHAR(30), kDate, 112)) IS NULL THEN 1 ELSE 0 END,
        CASE WHEN @SortDir = N'ASC'  THEN kText END ASC,  CASE WHEN @SortDir = N'DESC' THEN kText END DESC,
        CASE WHEN @SortDir = N'ASC'  THEN kNum  END ASC,  CASE WHEN @SortDir = N'DESC' THEN kNum  END DESC,
        CASE WHEN @SortDir = N'ASC'  THEN kDate END ASC,  CASE WHEN @SortDir = N'DESC' THEN kDate END DESC,
        ID
    OFFSET (@Page - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;

    UPDATE dbo.HSA_Adopt_SearchLog SET RowsReturned = @@ROWCOUNT WHERE SearchID = @SearchID;
END
GO

-- 10. ACCESS CONTROL ----------------------------------------------------
-- Paperboy connects as its own service login (GSAETL) and decides in its ACL
-- who may search; the roles below bound what that login can do here.
-- Searchers: EXECUTE on the two read procedures and nothing else. Ownership
-- chaining lets the procedures read the cards and write the search log on
-- their behalf, so a searcher can neither bypass the audit log nor edit it.
-- Maintainers: the rebuild, which TRUNCATEs the norm table (ALTER is needed
-- for that; chaining does not cover TRUNCATE).
IF DATABASE_PRINCIPAL_ID('HSA_Adopt_Searchers') IS NULL
    CREATE ROLE HSA_Adopt_Searchers;
GRANT EXECUTE ON dbo.HSA_Adopt_usp_SearchCards TO HSA_Adopt_Searchers;
GRANT EXECUTE ON dbo.HSA_Adopt_usp_BrowseCards TO HSA_Adopt_Searchers;
DENY  SELECT, INSERT, UPDATE, DELETE ON dbo.HSA_Adopt_SearchLog TO HSA_Adopt_Searchers;
DENY  SELECT ON dbo.HSA_Adopt_AdoptionCards        TO HSA_Adopt_Searchers;
DENY  SELECT ON dbo.HSA_Adopt_AdoptionCardsNorm    TO HSA_Adopt_Searchers;
DENY  SELECT ON dbo.HSA_Adopt_CaseGroups           TO HSA_Adopt_Searchers;
DENY  SELECT ON dbo.HSA_Adopt_CaseReviewOverrides  TO HSA_Adopt_Searchers;
GO
IF DATABASE_PRINCIPAL_ID('HSA_Adopt_Maintainers') IS NULL
    CREATE ROLE HSA_Adopt_Maintainers;
GRANT EXECUTE ON dbo.HSA_Adopt_usp_RebuildCaseGroups TO HSA_Adopt_Maintainers;
GRANT ALTER   ON dbo.HSA_Adopt_AdoptionCardsNorm     TO HSA_Adopt_Maintainers;
GO
-- The Paperboy service login (GSAETL). Its database-level EXECUTE already
-- covers the two read procedures, so it is NOT made a searcher: that role's
-- DENYs would then bind the service login too and block the maintenance
-- copy and rebuild. Only the maintainers grant adds anything it lacks.
IF IS_ROLEMEMBER('HSA_Adopt_Searchers', 'GSAETL') = 1
    ALTER ROLE HSA_Adopt_Searchers DROP MEMBER [GSAETL];
IF IS_ROLEMEMBER('HSA_Adopt_Maintainers', 'GSAETL') = 0
    ALTER ROLE HSA_Adopt_Maintainers ADD MEMBER [GSAETL];
GO

/* ---- Example calls ------------------------------------------------------
EXEC dbo.HSA_Adopt_usp_SearchCards @LastName = 'Baca',  @Reason = 'RR-2026-0142';
EXEC dbo.HSA_Adopt_usp_SearchCards @LastName = 'Regalando';              -- sounds-like catches 'Regalado'
EXEC dbo.HSA_Adopt_usp_SearchCards @CaseNumber = '117600';               -- partial, any punctuation
EXEC dbo.HSA_Adopt_usp_SearchCards @VEN_or_A = '17158';                  -- VEN on one card, A# on another
EXEC dbo.HSA_Adopt_usp_SearchCards @LastName = 'Lopez', @DOBYear = 2010; -- narrow a common surname
EXEC dbo.HSA_Adopt_usp_SearchCards @AnyText = '9-1003';                  -- stray number written in Notes

-- After each batch of newly keyed cards:
EXEC dbo.HSA_Adopt_usp_RebuildCaseGroups;

-- Recording a reviewer's decision (survives every future rebuild):
INSERT INTO dbo.HSA_Adopt_CaseReviewOverrides (ChildCardID, AdoptCardID, BirthCardID, Decision, ReviewedBy, ReviewNote)
VALUES (123, 456, 789, N'CONFIRMED', N'jgannon', N'Verified against the physical cards');
--------------------------------------------------------------------------- */
