-- {{{ Local variables

declare
   @sDate date = '2025-11-01'
  ,@eDate date = '2025-11-01'
  ,@sFyear varchar(4) = 'FY24'
  ,@eFyear varchar(4) = 'FY26'
  ,@startTimer datetime2
  ,@endTimer datetime2
  ,@type varchar(3) = 'GDS' 
  ,@cUnit varchar(4) = '3100' 
  ,@digits int = null
  ,@encumbered int = 0
;

-- ------------------------------------------------------------------------- }}}
-- {{{ Begin Timer statistics

set @startTimer = SysDateTime();

-- ------------------------------------------------------------------------- }}}
-- {{{ Paperboy queries

-- Scenario 0: 
-- Paperboy Reports Scaffolding retrieves sample data from GSABSS.dbo.TC60.
-- Sample data is used to produce an end-to-end report sample.
--
-- Test cycle:
-- rake reports:new[packing_slip]
-- rake reports:run[packing_slip,@sDate,@eDate]
-- rake reports:destroy[packing_slip]
-- A pdf file is written to paperboy/tmp
-- exec GSABSS.dbo.Paperboy_Reports_Scaffolding @sDate, @eDate;

-- Scenario 1:
-- Paperboy run the actual Billing File query. 
-- exec GSABSS.dbo.Export_TC60_To_Billing_File @sDate, @eDate, @type, @digits, @encumbered

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
