/* Merge long-format measurements with analyte-specific reference ranges.
   The source UNIT is retained and the reference unit is REF_UNIT.
   Dataset B must be unique by SUBJECT VISIT ANALYTE to avoid row multiplication.
   Values must be converted to REF_UNIT before comparison with LLN/ULN. */
%macro merge_lab_reference(
    data_a=,data_b=,out=,
    analyte_var=ANALYTE,
    low_var=LAB_LOW,
    high_var=LAB_HIGH,
    unit_var=UNIT
);
    %if not %sysfunc(exist(&data_a)) or not %sysfunc(exist(&data_b)) %then %do;
        %put ERROR: Input dataset A or B does not exist.;
        %return;
    %end;
    proc sql;
        create table &out as
        select a.*,
               b.&low_var as LLN,
               b.&high_var as ULN,
               b.&unit_var as REF_UNIT
        from &data_a as a
        left join &data_b as b
          on a.SUBJECT=b.SUBJECT
         and a.VISIT=b.VISIT
         and upcase(strip(a.ANALYTE))=upcase(strip(b.&analyte_var));
    quit;
%mend merge_lab_reference;

/* Example:
%merge_lab_reference(
    data_a=work.lab_long,data_b=work.lab_reference,out=work.lab_merged,
    analyte_var=LBTEST,low_var=LBSTNRLO,high_var=LBSTNRHI,
    unit_var=LBSTRESU
);
*/
