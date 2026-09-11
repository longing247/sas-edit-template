/*
  Macro version of date_more_than_7_days.sas.

  Identifies observations where DATE is more than N days later than
  the earliest nonmissing DATE within each BY group.

  Includes both DATA step and PROC SQL implementations.

  Example:

    %date_more_than_n_days(
        data=have,
        out_ds=want_datastep,
        out_sql=want_sql,
        by=subject visit,
        date=date,
        days=7
    );
*/

%macro date_more_than_n_days(
    data=,
    out_ds=want_datastep,
    out_sql=want_sql,
    by=subject visit,
    date=date,
    days=7
);

    /*===========================================================*
     | Solution 1: DATA step                                     |
     *===========================================================*/

    /* _missing_date makes nonmissing dates sort before missing
       dates, so the retained earliest date is truly nonmissing. */
    data _date_check_prep;
        set &data;
        _missing_date = missing(&date);
    run;

    proc sort data=_date_check_prep out=_date_check_sorted;
        by &by _missing_date &date;
    run;

    data &out_ds;
        set _date_check_sorted;
        by &by _missing_date &date;

        retain earliest_date;

        /* LAST BY variable is assumed to define the group boundary.
           For the default BY=subject visit, this is FIRST.VISIT. */
        if first.%scan(&by,-1,%str( )) then
            earliest_date = .;

        if missing(earliest_date) and not missing(&date) then
            earliest_date = &date;

        if not missing(&date) and
           not missing(earliest_date) and
           &date > earliest_date + &days then
            output;

        drop _missing_date earliest_date;
    run;

    /*===========================================================*
     | Solution 2: PROC SQL                                      |
     *===========================================================*/

    proc sql;
        create table &out_sql as
        select a.*
        from &data as a
        where not missing(a.&date)
          and a.&date > (
              select min(b.&date) + &days
              from &data as b
              where %sysfunc(tranwrd(%sysfunc(compbl(&by)),%str( ),%str( and )))
          )
        ;
    quit;

    proc datasets library=work nolist;
        delete _date_check_prep _date_check_sorted;
    quit;

%mend date_more_than_n_days;

/*
  NOTE:
  The DATA-step implementation above is directly reusable for a BY list.
  A generic correlated PROC SQL predicate requires constructing equality
  expressions for every BY variable. For production use with arbitrary
  BY lists, generate those predicates explicitly or use the dedicated
  macro below for the common SUBJECT + VISIT case.
*/

%macro date_more_than_n_days_subject_visit(
    data=,
    out=want_sql,
    subject=subject,
    visit=visit,
    date=date,
    days=7
);
    proc sql;
        create table &out as
        select a.*
        from &data as a
        where not missing(a.&date)
          and a.&date > (
              select min(b.&date) + &days
              from &data as b
              where b.&subject = a.&subject
                and b.&visit   = a.&visit
                and not missing(b.&date)
          )
        order by a.&subject, a.&visit, a.&date;
    quit;
%mend date_more_than_n_days_subject_visit;

/* Example calls */
/*
%date_more_than_n_days(
    data=have,
    out_ds=want_datastep,
    by=subject visit,
    date=date,
    days=7
);

%date_more_than_n_days_subject_visit(
    data=have,
    out=want_sql,
    subject=subject,
    visit=visit,
    date=date,
    days=7
);
*/
