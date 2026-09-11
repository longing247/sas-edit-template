/*
  Reusable macro: compare three datasets against one reference dataset
  by VISIT and output exceptions to separate datasets.

  Default rule:
      absolute datetime difference > 24 hours

  Assumptions:
    - Each dataset contains the BY, DATE and TIME variables.
    - DATE is a SAS date value.
    - TIME is a SAS time value.
    - One relevant observation per BY group per dataset.
*/

%macro compare_datetime(
    ref=,
    cmp1=,
    cmp2=,
    cmp3=,
    out1=out_cmp1,
    out2=out_cmp2,
    out3=out_cmp3,
    by=visit,
    date=date,
    time=time,
    hours=24
);

    proc sort data=&ref out=_ref_sorted;
        by &by;
    run;

    proc sort data=&cmp1 out=_cmp1_sorted;
        by &by;
    run;

    proc sort data=&cmp2 out=_cmp2_sorted;
        by &by;
    run;

    proc sort data=&cmp3 out=_cmp3_sorted;
        by &by;
    run;

    data &out1 &out2 &out3;
        merge
            _ref_sorted(
                in=inref
                rename=(&date=ref_date &time=ref_time)
            )
            _cmp1_sorted(
                in=incmp1
                rename=(&date=cmp1_date &time=cmp1_time)
            )
            _cmp2_sorted(
                in=incmp2
                rename=(&date=cmp2_date &time=cmp2_time)
            )
            _cmp3_sorted(
                in=incmp3
                rename=(&date=cmp3_date &time=cmp3_time)
            );
        by &by;

        if inref;

        ref_dt = dhms(ref_date, 0, 0, ref_time);

        if incmp1 and
           not missing(ref_dt) and
           not missing(cmp1_date) and
           not missing(cmp1_time) then do;
            cmp1_dt = dhms(cmp1_date, 0, 0, cmp1_time);
            if abs(cmp1_dt - ref_dt) > (&hours * 60 * 60) then
                output &out1;
        end;

        if incmp2 and
           not missing(ref_dt) and
           not missing(cmp2_date) and
           not missing(cmp2_time) then do;
            cmp2_dt = dhms(cmp2_date, 0, 0, cmp2_time);
            if abs(cmp2_dt - ref_dt) > (&hours * 60 * 60) then
                output &out2;
        end;

        if incmp3 and
           not missing(ref_dt) and
           not missing(cmp3_date) and
           not missing(cmp3_time) then do;
            cmp3_dt = dhms(cmp3_date, 0, 0, cmp3_time);
            if abs(cmp3_dt - ref_dt) > (&hours * 60 * 60) then
                output &out3;
        end;

        format ref_dt cmp1_dt cmp2_dt cmp3_dt datetime20.;
    run;

    proc datasets library=work nolist;
        delete _ref_sorted _cmp1_sorted _cmp2_sorted _cmp3_sorted;
    quit;

%mend compare_datetime;

/* Example call */
%compare_datetime(
    ref=a,
    cmp1=b,
    cmp2=c,
    cmp3=d,
    out1=out_b,
    out2=out_c,
    out3=out_d,
    by=visit,
    date=date,
    time=time,
    hours=24
);
