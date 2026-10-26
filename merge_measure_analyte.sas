/* Merge wide lab measures with long analyte reference ranges.
   Parallel positional lists: measures=LBRES_CREAT LBRES_ALT
   analytes=CREATININE ALAT
   Output: CREAT_LOW CREAT_HIGH ALT_LOW ALT_HIGH.
   Assumes B is unique by keys + analyte_var; duplicate matches
   can multiply output rows. */
%macro merge_measure_analyte(
    data_a=, data_b=, out=,
    measures=, analytes=,
    keys=SUBJECT VISIT,
    analyte_var=ANALYTE,
    low_var=LAB_LOW,
    high_var=LAB_HIGH,
    prefix=LBRES_
);
    %local n n_analytes nkeys i j measure analyte code key;
    %let n=%sysfunc(countw(&measures));
    %let n_analytes=%sysfunc(countw(&analytes));
    %let nkeys=%sysfunc(countw(&keys));

    %if &n=0 or &n ne &n_analytes or &nkeys=0 %then %do;
        %put ERROR: Invalid measures, analytes or keys lists.;
        %return;
    %end;

    %do i=1 %to &n;
        %let measure=%scan(%superq(measures),&i,%str( ));
        %if %upcase(%substr(&measure,1,%length(&prefix))) ne
            %upcase(&prefix) %then %do;
            %put ERROR: &measure does not begin with &prefix..;
            %return;
        %end;
    %end;

    proc sql;
        create table &out as
        select a.*
        %do i=1 %to &n;
            %let measure=%scan(%superq(measures),&i,%str( ));
            %let code=%substr(&measure,%eval(%length(&prefix)+1));
            , b&i..&low_var  as &code._LOW
            , b&i..&high_var as &code._HIGH
        %end;
        from &data_a as a
        %do i=1 %to &n;
            %let analyte=%scan(%superq(analytes),&i,%str( ));
            left join &data_b as b&i
                on
                %do j=1 %to &nkeys;
                    %let key=%scan(%superq(keys),&j,%str( ));
                    %if &j>1 %then and;
                    a.&key=b&i..&key
                %end;
                and b&i..&analyte_var="&analyte"
        %end;
        ;
    quit;
%mend merge_measure_analyte;

/* Example:
%merge_measure_analyte(
    data_a=work.lab_wide,
    data_b=work.lab_reference,
    out=work.lab_merged,
    measures=LBRES_CREAT LBRES_ALT LBRES_AST,
    analytes=CREATININE ALAT ASAT,
    keys=SUBJECT VISIT,
    analyte_var=LBTEST,
    low_var=LBSTNRLO,
    high_var=LBSTNRHI
);
*/
