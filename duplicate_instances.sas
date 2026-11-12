/* Identify pairs of instances with identical date and time within a subject.
   Input: HAVE (USUBJID, INSTANCE, DATE, TIME)
   Output: WANT (USUBJID, INSTANCE, DUP_INSTANCE)
   Each pair is reported once (INSTANCE < DUP_INSTANCE).
*/
proc sql;
    create table want as
    select a.usubjid,
           a.instance,
           b.instance as dup_instance
    from have as a, have as b
    where a.usubjid = b.usubjid
      and a.date = b.date
      and a.time = b.time
      and a.instance < b.instance;
quit;
