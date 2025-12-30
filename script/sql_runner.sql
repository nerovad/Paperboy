-- {{{ Local variables

declare
   @sDate date = '2025-11-01'
  ,@eDate date = '2025-11-01'
  ,@startTimer datetime2
  ,@endTimer datetime2
  ,@type varchar(3) = null
  ,@cUnit varchar(4) = null
;

-- ------------------------------------------------------------------------- }}}
-- {{{ Begin Timer statistics

set @startTimer = SysDateTime();

-- ------------------------------------------------------------------------- }}}
-- {{{ Paperboy queries

-- Paperboy Reports Scaffolding retrieves sample data from GSABSS.dbo.TC60.
-- Sample data is used to produce an end-to-end report sample.
--
-- Test cycle:
-- rake reports:new[packing_slip]
-- rake reports:run[packing_slip,@sDate,@eDate]
-- rake reports:destroy[packing_slip]
-- A pdf file is written to paperboy/tmp
exec GSABSS.dbo.Paperboy_Reports_Scaffolding @sDate, @eDate;

-- ------------------------------------------------------------------------- }}}
-- {{{ End Timer statistics

set @endTimer = SysDateTime();
select
   @startTimer as '@startTimer'
  ,@endTimer as '@endTimer'
  ,datediff(millisecond, @startTimer, @endTimer) as 'duration_in_ms'
  ,@sDate as '@sDate'
  ,@eDate as '@eDate'
;

-- ------------------------------------------------------------------------- }}}
