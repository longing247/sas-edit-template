/*
  Convert wide-format measures in A to long format and join to B.

  A: one row per subject/visit, numeric variables ALT AST TBILI etc.
  B: subject, visit, analyte variable (configurable), std_measure.

  MEASURES= is a space-separated list of UNQUOTED numeric variable names.
  ANALYTES= is a space-separated list of QUOTED character labels,
            in the same order as MEASURES=.

  Output: one row per A measure per subject/visit, with measure_name,
          measure_value, analyte and matching std_measure from B.
  Missing matches in B retain the A measure with missing std_measure.
  Multiple matches in B produce multiple output rows (SQL left join).
*/

%macro merge_measure_analyte(
    a=,
    b=,
    out=,
    measures=,
    analytes=,
    b_analyte=analyte
);

    %if %superq(a)= or %superq(b)= or %superq(out)= or
        %superq(measures)= or %superq(analytes)= %then %do;
        %put ERROR: A=, B=, OUT=, MEASURES= and ANALYTES= are required.;
        %return;
    %end;

    data _mma_a_long;
        set &a;
        length measure_name $32 analyte $100;
        array _mma_values[*] &measures;
        array _mma_analytes[*] $100 _temporary_ (&analytes);

        if dim(_mma_values) ne dim(_mma_analytes) then do;
            putlog 'ERROR: MEASURES and ANALYTES must have the same number of elements.';
            stop;
        end;

        do _mma_i = 1 to dim(_mma_values);
            measure_name = vname(_mma_values[_mma_i]);
            measure_value = _mma_values[_mma_i];
            analyte = _mma_analytes[_mma_i];
            output;
        end;

        keep subject visit measure_name measure_value analyte;
    run;

    %if &syserr > 4 %then %do;
        %put ERROR: Unable to create the mapped long dataset.;
        %return;
    %end;

    proc sql;
        create table &out as
        select a.subject,
               a.visit,
               a.measure_name,
               a.measure_value,
               a.analyte,
               b.std_measure
        from _mma_a_long as a
        left join &b as b
          on a.subject = b.subject
         and a.visit = b.visit
         and upcase(strip(a.analyte)) =
             upcase(strip(b.&b_analyte))
        ;
    quit;

    proc datasets library=work nolist;
        delete _mma_a_long;
    quit;

%mend merge_measure_analyte;

/* Example:
%merge_measure_analyte(
    a=work.a,
    b=work.b,
    out=work.want,
    measures=ALT AST TBILI,
    analytes='ALANINE AMINOTRANSFERASE'
             'ASPARTATE AMINOTRANSFERASE'
             'BILIRUBIN',
    b_analyte=LBTEST
);
*/
