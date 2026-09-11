/*
  SAS Edit
  Example: identify dates more than 7 days after the earliest date
  for each SUBJECT + VISIT combination.

  Assumptions:
    - DATE is a SAS date value, not a datetime value.
    - Output contains only SUBJECT, VISIT, and DATE for offending records.
*/

/*---------------------------------------------------------------*
 | Example input data                                             |
 *---------------------------------------------------------------*/
data have;
    input subject $ visit $ date :date9.;
    format date date9.;
    datalines;
001 V1 01JAN2026
001 V1 05JAN2026
001 V1 09JAN2026
001 V2 15JAN2026
001 V2 24JAN2026
002 V1 03FEB2026
002 V1 07FEB2026
002 V1 10FEB2026
002 V1 12FEB2026
;
run;


/*===============================================================*
 | Solution 1: DATA step                                         |
 *===============================================================*/

/* Sort so the first observation in each SUBJECT + VISIT group
   contains the earliest nonmissing DATE. */
proc sort data=have out=have_sorted;
    by subject visit date;
run;

data want_datastep(keep=subject visit date);
    set have_sorted;
    by subject visit date;

    retain earliest_date;

    if first.visit then
        earliest_date = date;

    if not missing(date) and
       date > earliest_date + 7 then
        output;
run;


/*===============================================================*
 | Solution 2: PROC SQL                                          |
 *===============================================================*/

proc sql;
    create table want_sql as
    select subject,
           visit,
           date
    from have
    group by subject, visit
    having not missing(date)
       and date > min(date) + 7
    order by subject, visit, date
    ;
quit;
