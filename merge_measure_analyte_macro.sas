/*
  Merge dataset A with dataset B using a measure-to-analyte mapping.

  A: subject, visit, measure
  B: subject, visit, <b_analyte>, std_measure

  The MEASURES= and ANALYTES= macro parameters are parallel lists.
  Element i of MEASURES maps to element i of ANALYTES.
*/

%macro merge_measure_analyte(
    a=,
    b=,
    out=,
    measures=,
    analytes=,
    b_analyte=analyte
);

    data _a_mapped;
        length analyte $100;
        set &a;
        call missing(analyte);

        array measure_map[*] $100 _temporary_ (&measures);
        array analyte_map[*] $100 _temporary_ (&analytes);

        do _i = 1 to dim(measure_map);
            if strip(upcase(measure)) =
               strip(upcase(measure_map[_i])) then do;
                analyte = analyte_map[_i];
                leave;
            end;
        end;

        drop _i;
    run;

    proc sort data=_a_mapped;
        by subject visit analyte;
    run;

    /* Normalize the analyte key name in B without modifying B. */
    proc sort data=&b(rename=(&b_analyte=analyte)) out=_b_sorted;
        by subject visit analyte;
    run;

    data &out;
        merge _a_mapped(in=ina)
              _b_sorted(
                  keep=subject visit analyte std_measure
              );
        by subject visit analyte;

        if ina;
    run;

    proc datasets library=work nolist;
        delete _a_mapped _b_sorted;
    quit;

%mend;


/* Example

%let measures =
    'ALT'
    'AST'
    'TBILI';

%let analytes =
    'ALANINE AMINOTRANSFERASE'
    'ASPARTATE AMINOTRANSFERASE'
    'BILIRUBIN';

%merge_measure_analyte(
    a=work.a,
    b=work.b,
    out=work.want,
    measures=&measures,
    analytes=&analytes,
    b_analyte=LBTEST
);

*/
