select 
   (select count(*) from GSABSS.dbo.companions) as "#Companions"
  ,(select count(*) from GSABSS.dbo.daily_presorts) as "#Daily Presorts"
  ,(select count(*) from GSABSS.dbo.move_results) as "Move Results"
;

-- truncate table GSABSS.dbo.companions;
-- truncate table GSABSS.dbo.daily_presorts;
-- truncate table GSABSS.dbo.move_results;
-- truncate table GSABSS.dbo.p2m_oms_upload_files;
-- truncate table GSABSS.dbo.p2m_oms_upload_findings;

-- delete from GSABSS.dbo.p2m_oms_uploads where oms_number is not null;