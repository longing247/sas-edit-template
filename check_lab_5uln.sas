/* One result per SUBJECT, VISIT and ANALYTE.
   Requires input sorted by SUBJECT VISIT ANALYTE.
   STD_VALUE and ULN must be in the same units.
   1 = any valid measurement > 5*ULN
   0 = valid measurements exist, none > 5*ULN
   . = no valid comparison
*/
%macro check_lab_5uln(data=,out=);
data &out;
    set &data;
    by SUBJECT VISIT ANALYTE;
    retain GT_5ULN;

    if first.ANALYTE then GT_5ULN=.;

    if not missing(STD_VALUE) and not missing(ULN) and ULN>0 then do;
        if STD_VALUE>5*ULN then GT_5ULN=1;
        else if missing(GT_5ULN) then GT_5ULN=0;
    end;

    if last.ANALYTE then output;
    keep SUBJECT VISIT ANALYTE GT_5ULN;
run;
%mend check_lab_5uln;

/* Example:
proc sort data=work.lab_merged;
    by SUBJECT VISIT ANALYTE;
run;
%check_lab_5uln(data=work.lab_merged,out=work.lab_summary);
*/
