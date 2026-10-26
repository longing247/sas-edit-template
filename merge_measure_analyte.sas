/* Merge wide lab results with long reference ranges, preserving original
   measurements. Conversion factors are analyte-specific:
   standardized_value = original_value * FACTOR + OFFSET.
   B must be unique by KEYS + ANALYTE_VAR.
   Conversion table must be unique by ANALYTE, FROM_UNIT, TO_UNIT.
   Units are compared case-insensitively after stripping spaces at edges.
   Missing/unrecognized conversions yield missing _STD and a status. */
%macro merge_measure_analyte(
    data_a=, data_b=, out=,
    measures=, analytes=,
    keys=SUBJECT VISIT,
    analyte_var=ANALYTE,
    low_var=LAB_LOW,
    high_var=LAB_HIGH,
    prefix=LBRES_,
    unit_prefix=LBUNIT_,
    ref_unit_var=UNIT,
    conversion_ds=
);
    %local n n_analytes nkeys i j measure analyte code key dsid rc
           required;
    %let n=%sysfunc(countw(&measures));
    %let n_analytes=%sysfunc(countw(&analytes));
    %let nkeys=%sysfunc(countw(&keys));

    %if &n=0 or &n ne &n_analytes or &nkeys=0 %then %do;
        %put ERROR: Invalid parallel lists or keys.;
        %return;
    %end;
    %if not %sysfunc(exist(&data_a)) or not %sysfunc(exist(&data_b)) %then %do;
        %put ERROR: Input dataset A or B does not exist.;
        %return;
    %end;
    %if %length(%superq(conversion_ds)) %then %do;
        %if not %sysfunc(exist(&conversion_ds)) %then %do;
            %put ERROR: Conversion dataset does not exist.;
            %return;
        %end;
    %end;

    /* Check expected source variables before generating SQL. */
    %let dsid=%sysfunc(open(&data_a,i));
    %if &dsid=0 %then %do;
        %put ERROR: Cannot open &data_a..;
        %return;
    %end;
    %do i=1 %to &n;
        %let measure=%scan(&measures,&i);
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
        %if %length(&code)>27 %then %do;
            %put ERROR: &code is too long for generated variable names.;
            %let rc=%sysfunc(close(&dsid));
            %return;
        %end;
        %if %sysfunc(varnum(&dsid,&measure))=0 or
            %sysfunc(varnum(&dsid,&unit_prefix.&code))=0 %then %do;
            %put ERROR: Missing &measure or &unit_prefix.&code in A.;
            %let rc=%sysfunc(close(&dsid));
            %return;
        %end;
        %if %sysfunc(vartype(&dsid,%sysfunc(varnum(&dsid,&measure)))) ne N %then %do;
            %put ERROR: &measure must be numeric.;
            %let rc=%sysfunc(close(&dsid));
            %return;
        %end;
        %if %sysfunc(vartype(&dsid,%sysfunc(varnum(&dsid,&unit_prefix.&code)))) ne C %then %do;
            %put ERROR: &unit_prefix.&code must be character.;
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

    /* Reference values and units are joined per analyte. */
    proc sql;
        create table &out as
        select a.*
        %do i=1 %to &n;
            %let measure=%scan(&measures,&i);
            %let analyte=%scan(&analytes,&i);
            %let code=%substr(&measure,%eval(%length(&prefix)+1));
            , b&i..&low_var as &code._LOW
            , b&i..&high_var as &code._HIGH
            , b&i..&ref_unit_var as &code._UNIT
            , case
                when missing(a.&measure) then .
                when missing(b&i..&ref_unit_var) or
                     missing(a.&unit_prefix.&code) then .
                when upcase(strip(a.&unit_prefix.&code)) =
                     upcase(strip(b&i..&ref_unit_var))
                     then a.&measure
                %if %length(%superq(conversion_ds)) %then %do;
                when not missing(c&i..FACTOR)
                     then a.&measure*c&i..FACTOR + coalesce(c&i..OFFSET,0)
                %end;
                else .
              end as &code._STD
            , case
                when missing(a.&measure) then 'MISSING_VALUE'
                when missing(b&i..&ref_unit_var) then 'NO_REFERENCE'
                when missing(a.&unit_prefix.&code) then 'NO_SOURCE_UNIT'
                when upcase(strip(a.&unit_prefix.&code)) =
                     upcase(strip(b&i..&ref_unit_var)) then 'MATCH'
                %if %length(%superq(conversion_ds)) %then %do;
                when not missing(c&i..FACTOR) then 'CONVERTED'
                %end;
                else 'NO_CONVERSION'
              end as &code._STATUS length=16
        %end;
        from &data_a as a
        %do i=1 %to &n;
            %let analyte=%scan(&analytes,&i);
            %let measure=%scan(&measures,&i);
            %let code=%substr(&measure,%eval(%length(&prefix)+1));
            left join &data_b as b&i
                on
                %do j=1 %to &nkeys;
                    %let key=%scan(&keys,&j);
                    %if &j>1 %then and;
                    a.&key=b&i..&key
                %end;
                and b&i..&analyte_var="&analyte"
            %if %length(%superq(conversion_ds)) %then %do;
                left join &conversion_ds as c&i
                  on upcase(strip(c&i..ANALYTE))=upcase("&analyte")
                 and upcase(strip(c&i..FROM_UNIT))=
                     upcase(strip(a.&unit_prefix.&code))
                 and upcase(strip(c&i..TO_UNIT))=
                     upcase(strip(b&i..&ref_unit_var))
            %end;
        %end;
        ;
    quit;
%mend merge_measure_analyte;

/* Example conversion lookup table (values are illustrative; validate
   factors, units, and analyte-specific methods against lab specifications):
data work.lab_conversion;
    length analyte $32 from_unit to_unit $20;
    input analyte $ from_unit $ to_unit $ factor offset;
    datalines;
CREATININE mg/dL umol/L 88.4 0
GLUCOSE mg/dL mmol/L 0.0555 0
;
run;

%merge_measure_analyte(
    data_a=work.lab_wide,
    data_b=work.lab_reference,
    out=work.lab_merged,
    measures=LBRES_CREAT LBRES_GLU,
    analytes=CREATININE GLUCOSE,
    keys=SUBJECT VISIT,
    analyte_var=LBTEST,
    low_var=LBSTNRLO,
    high_var=LBSTNRHI,
    ref_unit_var=LBSTRESU,
    conversion_ds=work.lab_conversion
);
*/
