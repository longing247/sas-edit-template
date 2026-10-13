/*
  Merge wide-format A with analyte observations from B.
  A: subject visit ALT AST TBILI
  B: subject visit LBTEST std_measure

  B is pivoted to one row per subject/visit using parallel arrays.
  Original A variables are preserved; B values become ALT_STD,
  AST_STD and TBILI_STD. For duplicate analytes within a group,
  the last observation in B's sorted order wins.
  Assumes one row per subject/visit in A and numeric std_measure.
*/
%macro merge_measure_analyte(a=, b=, out=, b_analyte=LBTEST);
    proc sort data=&b out=_mma_b_sorted;
        by subject visit;
    run;

    data _mma_b_wide;
        set _mma_b_sorted(keep=subject visit &b_analyte std_measure);
        by subject visit;

        array values[3] ALT_STD AST_STD TBILI_STD;
        array names[3] $100 _temporary_ (
            'ALANINE AMINOTRANSFERASE'
            'ASPARTATE AMINOTRANSFERASE'
            'BILIRUBIN'
        );

        retain ALT_STD AST_STD TBILI_STD;

        if first.visit then call missing(of ALT_STD AST_STD TBILI_STD);

        do i = 1 to dim(names);
            if upcase(strip(&b_analyte)) = names[i] then
                values[i] = std_measure;
        end;

        if last.visit then output;
        keep subject visit ALT_STD AST_STD TBILI_STD;
    run;

    proc sort data=&a out=_mma_a_sorted;
        by subject visit;
    run;

    data &out;
        merge _mma_a_sorted(in=ina) _mma_b_wide;
        by subject visit;
        if ina;
    run;

    proc datasets library=work nolist;
        delete _mma_a_sorted _mma_b_sorted _mma_b_wide;
    quit;
%mend merge_measure_analyte;

/* Example:
%merge_measure_analyte(
    a=work.A,
    b=work.B,
    out=work.want,
    b_analyte=LBTEST
);
*/
