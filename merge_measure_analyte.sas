/* Merge wide lab results with long reference ranges, preserving original
   measurements. Conversion factors are analyte-specific:
   standardized_value = original_value * FACTOR + OFFSET.
   B must be unique by KEYS + ANALYTE_VAR.
   Conversion table must be unique by ANALYTE, FROM_UNIT, TO_UNIT.
   Units are compared case-insensitively after stripping spaces at edges.
   Missing/unrecognized conversions yield missing _STD and a status. */
%macro merge_measure_analyte(
    data_a=, data_b=, out=,
    measures=, analytes=, units=,
    keys=SUBJECT VISIT,
    analyte_var=ANALYTE,
    low_var=LAB_LOW,
    high_var=LAB_HIGH,
    prefix=LBRES_,
    ref_unit_var=UNIT,
);
    %local n n_analytes n_units nkeys i j measure analyte unit code key dsid rc required;
    %let n=%sysfunc(countw(&measures));
    %let n_analytes=%sysfunc(countw(&analytes));
    %let n_units=%sysfunc(countw(&units));
    %let nkeys=%sysfunc(countw(&keys));

    %if &n=0 or &n ne &n_analytes or &n ne &n_units or &nkeys=0 %then %do;
        %put ERROR: Invalid parallel lists or keys.;
        %return;
    %end;
    %if not %sysfunc(exist(&data_a)) or not %sysfunc(exist(&data_b)) %then %do;
        %put ERROR: Input dataset A or B does not exist.;
        %return;
    %end;
    /* Check expected source variables before generating SQL. */
    %let dsid=%sysfunc(open(&data_a,i));
    %if &dsid=0 %then %do;
        %put ERROR: Cannot open &data_a..;
        %return;
    %end;
    %do i=1 %to &n;
        %let measure=%scan(&measures,&i);
        %let unit=%scan(&units,&i);
        %if %length(&measure)<=%length(&prefix) %then %do;
            %put ERROR: Invalid measure &measure..;
            %let rc=%sysfunc(close(&dsid));
            %return;
        %end;
        %if %upcase(%substr(&measure,1,%length(&prefix))) ne %upcase(&prefix) %then %do;
            %put ERROR: &measure does not begin with &prefix..;
            %let rc=%sysfunc(close(&dsid));
            %return;
        %end;
        %let code=%substr(&measure,%eval(%length(&prefix)+1));
        %if %length(&code)>25 %then %do;
            %put ERROR: &code is too long for generated variable names.;
            %let rc=%sysfunc(close(&dsid));
            %return;
        %end;
        %if %sysfunc(varnum(&dsid,&measure))=0 or
            %sysfunc(varnum(&dsid,&unit))=0 %then %do;
            %put ERROR: Missing &measure or &unit in A.;
            %let rc=%sysfunc(close(&dsid));
            %return;
        %end;
        %if %sysfunc(vartype(&dsid,%sysfunc(varnum(&dsid,&measure)))) ne N %then %do;
            %put ERROR: &measure must be numeric.;
            %let rc=%sysfunc(close(&dsid));
            %return;
        %end;
        %if %sysfunc(vartype(&dsid,%sysfunc(varnum(&dsid,&unit)))) ne C %then %do;
            %put ERROR: &unit must be character.;
            %let rc=%sysfunc(close(&dsid));
            %return;
        %end;
        %if %sysfunc(varnum(&dsid,&code._STD)) or
            %sysfunc(varnum(&dsid,&code._LOW)) or
            %sysfunc(varnum(&dsid,&code._HIGH)) or
            %sysfunc(varnum(&dsid,&code._UNIT)) or
            %sysfunc(varnum(&dsid,&code._STATUS)) %then %do;
            %put ERROR: Generated output variable already exists in A for &code..;
            %let rc=%sysfunc(close(&dsid));
            %return;
        %end;
    %end;
    %do j=1 %to &nkeys;
        %let key=%scan(&keys,&j);
        %if %sysfunc(varnum(&dsid,&key))=0 %then %do;
            %put ERROR: Key &key missing in A.;
            %let rc=%sysfunc(close(&dsid));
            %return;
        %end;
    %end;
    %let rc=%sysfunc(close(&dsid));

    %let dsid=%sysfunc(open(&data_b,i));
    %if &dsid=0 %then %do;
        %put ERROR: Cannot open &data_b..;
        %return;
    %end;
    %let required=&analyte_var &low_var &high_var &ref_unit_var &keys;
    %do j=1 %to %sysfunc(countw(&required));
        %let key=%scan(&required,&j);
        %if %sysfunc(varnum(&dsid,&key))=0 %then %do;
            %put ERROR: Variable &key missing in B.;
            %let rc=%sysfunc(close(&dsid));
            %return;
        %end;
    %end;
    %let rc=%sysfunc(close(&dsid));

    /* Join reference data only; perform conversions in the DATA step. */
    proc sql;
        create table &out as
        select a.*
        %do i=1 %to &n;
            %let measure=%scan(&measures,&i);
            %let code=%substr(&measure,%eval(%length(&prefix)+1));
            , b&i..&low_var as &code._LOW
            , b&i..&high_var as &code._HIGH
            , b&i..&ref_unit_var as &code._UNIT
        %end;
        from &data_a as a
        %do i=1 %to &n;
            %let analyte=%scan(&analytes,&i);
            left join &data_b as b&i
              on
              %do j=1 %to &nkeys;
                  %let key=%scan(&keys,&j);
                  %if &j>1 %then and;
                  a.&key=b&i..&key
              %end;
              and upcase(strip(b&i..&analyte_var))=upcase("&analyte")
        %end;
        ;
    quit;
    %if &sqlrc ne 0 %then %do;
        %put ERROR: Reference merge failed.;
        %return;
    %end;

    data &out;
        set &out;
        length _cl_from _cl_to $80 _cl_analyte $32;
        %do i=1 %to &n;
            %let measure=%scan(&measures,&i);
            %let analyte=%scan(&analytes,&i);
            %let unit=%scan(&units,&i);
            %let code=%substr(&measure,%eval(%length(&prefix)+1));
            %convert_lab_unit_step(
                value=&measure, analyte=&analyte, from=&unit,
                to=&code._UNIT, result=&code._STD, status=&code._STATUS
            );
        %end;
        drop _cl_:;
    run;
%mend merge_measure_analyte;

/* Load convert_count_unit_macro.sas before invoking this macro.
   Example:
   %merge_measure_analyte(
       data_a=work.lab_wide, data_b=work.lab_reference, out=work.lab_merged,
       measures=LBRES_CREAT LBRES_GLU LBRES_WBC,
       analytes=CREATININE GLUCOSE WBC,
       units=LBUNIT_CREAT LBUNIT_GLU LBUNIT_WBC,
       analyte_var=LBTEST, low_var=LBSTNRLO, high_var=LBSTNRHI,
       ref_unit_var=LBSTRESU
   );
*/
