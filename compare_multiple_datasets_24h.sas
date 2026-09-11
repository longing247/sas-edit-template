/*
  Compare datasets B, C and D with reference dataset A by VISIT.

  Assumptions:
    - A, B, C and D contain VISIT, DATE and TIME.
    - DATE is a SAS date value.
    - TIME is a SAS time value.
    - Datasets are sorted by VISIT before the DATA step.
    - One relevant observation per VISIT per dataset.
    - A is the reference dataset.

  Output:
    OUT_B: observations where B is more than 24 hours from A
    OUT_C: observations where C is more than 24 hours from A
    OUT_D: observations where D is more than 24 hours from A

  ABS() means the comparison is in either direction (earlier or later).
*/

proc sort data=a; by visit; run;
proc sort data=b; by visit; run;
proc sort data=c; by visit; run;
proc sort data=d; by visit; run;

data out_b out_c out_d;
    merge
        a(in=ina rename=(date=a_date time=a_time))
        b(in=inb rename=(date=b_date time=b_time))
        c(in=inc rename=(date=c_date time=c_time))
        d(in=ind rename=(date=d_date time=d_time));
    by visit;

    /* Only evaluate visits present in reference dataset A. */
    if ina;

    a_dt = dhms(a_date, 0, 0, a_time);

    /* B vs A */
    if inb then do;
        b_dt = dhms(b_date, 0, 0, b_time);
        if abs(b_dt - a_dt) > 86400 then
            output out_b;
    end;

    /* C vs A */
    if inc then do;
        c_dt = dhms(c_date, 0, 0, c_time);
        if abs(c_dt - a_dt) > 86400 then
            output out_c;
    end;

    /* D vs A */
    if ind then do;
        d_dt = dhms(d_date, 0, 0, d_time);
        if abs(d_dt - a_dt) > 86400 then
            output out_d;
    end;

    format a_dt b_dt c_dt d_dt datetime20.;
run;
