/* Reshape wide LBRES_<code> and LBRES_<code>_UN into long records.
   Numeric measurement values are read directly, preserving precision.
   Requires numeric measurements and character unit variables. */
%macro reshape_lab(data=,out=,codes=,analytes=);
    %local n i code analyte;
    %let n=%sysfunc(countw(&codes));
    %if &n=0 or &n ne %sysfunc(countw(&analytes)) %then %do;
        %put ERROR: CODES and ANALYTES must be nonempty parallel lists.;
        %return;
    %end;
    %if not %sysfunc(exist(&data)) %then %do;
        %put ERROR: Input dataset &data does not exist.;
        %return;
    %end;

    data &out;
        set &data;
        length CODE $32 ANALYTE $40 UNIT $200;
        format VALUE best32.;
        %do i=1 %to &n;
            %let code=%scan(&codes,&i);
            %let analyte=%scan(&analytes,&i);
            CODE="&code";
            ANALYTE="&analyte";
            VALUE=LBRES_&code;
            UNIT=LBRES_&code._UN;
            if not missing(VALUE) then output;
        %end;
        keep SUBJECT VISIT CODE ANALYTE VALUE UNIT;
    run;
%mend reshape_lab;

/* Example:
%reshape_lab(data=work.lab_wide,out=work.lab_long,
             codes=CA GLU CREAT,analytes=Calcium Glucose Creatinine);
*/
