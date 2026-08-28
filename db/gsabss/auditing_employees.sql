select * from GSAStores.dbo.employees 
 where id in (135272, 136192) 
    or job_title like 'Director%' 
    or job_title = 'County Supervisor'
    order by id;
--select count(*) from GSAStores.dbo.employees;
--select * from GSAStores.dbo.employees where id = supervisor_id;
--select * from GSAStores.dbo.employees where supervisor_id is null order by unit, job_title;