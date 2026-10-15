/*
 * Two validations:
 * 1. Consecutive 'N' within subject and status variable, across procedure
 *    and assessment datasets.
 * 2. More than 40% 'N' per status variable, procedure datasets only.
 *
 * Assumptions: CPDRV.x<dataset> inputs; SUBJECT is character;
 * InstanceName and FolderSeq are available ordering columns.
 * EDIT is an assigned output libref.
 */
%macro pd_no_edit(p_ds=, a_ds=, edit=, edit1=, edit2=);
    %local all_ds n_all i ds ds_prefix varlist nvars is_proc list1 list2;

    %let all_ds = &p_ds &a_ds;
    %let n_all = %sysfunc(countw(%superq(all_ds), %str( )));
    %let list1=;
    %let list2=;

    %if &n_all = 0 %then %do;
        %put ERROR: Both dataset lists are empty.;
        %return;
    %end;

    %do i = 1 %to &n_all;
        %let ds = %scan(%superq(all_ds), &i, %str( ));
        %let ds_prefix = %scan(&ds, 1, _);
        %let varlist=;

        %if not %sysfunc(exist(cpdrv.x&ds)) %then %do;
            %put ERROR: Input dataset cpdrv.x&ds does not exist.;
            %return;
        %end;

        proc contents data=cpdrv.x&ds
            out=work._pd_vars(keep=name type varnum) noprint;
        run;

        proc sql noprint;
            select nliteral(name) into :varlist separated by ' '
            from work._pd_vars
            where type = 2
              and prxmatch("/^&ds_prefix.STAT(_.*)?_STD$/i", strip(name)) > 0
            order by varnum;
        quit;

        %let nvars = %sysfunc(countw(%superq(varlist), %str( )));
        %if &nvars = 0 %then %do;
            %put NOTE: No matching status variables in &ds..;
        %end;
        %else %do;
            proc sort data=cpdrv.x&ds out=work._pd_sorted;
                by SUBJECT InstanceName FolderSeq;
            run;

            /* Transpose statuses to a long dataset, one row per variable. */
            data work._pd_long;
                set work._pd_sorted;
                length variable $32 value $200;
                array status_vars[&nvars] $ &varlist;
                do j = 1 to dim(status_vars);
                    variable = vname(status_vars[j]);
                    value = status_vars[j];
                    output;
                end;
                keep SUBJECT InstanceName FolderSeq variable value;
            run;

            proc sort data=work._pd_long;
                by SUBJECT variable InstanceName FolderSeq;
            run;

            /* LAG queues are advanced unconditionally for each observation. */
            data work._pd_e1_&i;
                set work._pd_long;
                length source_ds $32 rule $40 prev_subject $200
                       prev_variable $32 prev_value $200;
                prev_subject = lag(SUBJECT);
                prev_variable = lag(variable);
                prev_value = lag(value);
                source_ds = "&ds";
                rule = "CONSECUTIVE_N";
                if SUBJECT = prev_subject and variable = prev_variable
                   and upcase(strip(value)) = 'N'
                   and upcase(strip(prev_value)) = 'N'
                then output;
                keep source_ds SUBJECT InstanceName FolderSeq variable value rule;
            run;
            %let list1 = &list1 work._pd_e1_&i;

            %let is_proc = %sysfunc(findw(%superq(p_ds), %superq(ds), %str( )));
            %if &is_proc > 0 %then %do;
                /* One summary per matching status variable. */
                proc sql;
                    create table work._pd_e2_&i as
                    select "&ds" as source_ds length=32,
                           variable,
                           "N_OVER_40_PERCENT" as rule length=40,
                           count(*) as total,
                           sum(upcase(strip(value)) = 'N') as n_count,
                           calculated n_count / calculated total * 100
                               as pct_n
                    from work._pd_long
                    group by variable
                    having calculated pct_n > 40;
                quit;
                %let list2 = &list2 work._pd_e2_&i;
            %end;
        %end;
    %end;

    /* Create empty outputs with consistent structure when no matches exist. */
    %if %length(%superq(list1)) > 0 %then %do;
        data &edit..&edit1;
            set &list1;
        run;
    %end;
    %else %do;
        data &edit..&edit1;
            length source_ds $32 SUBJECT $200 InstanceName $200
                   FolderSeq 8 variable $32 value $200 rule $40;
            stop;
        run;
    %end;

    %if %length(%superq(list2)) > 0 %then %do;
        data &edit..&edit2;
            set &list2;
        run;
    %end;
    %else %do;
        data &edit..&edit2;
            length source_ds $32 variable $32 rule $40
                   total n_count pct_n 8;
            stop;
        run;
    %end;
%mend pd_no_edit;

/* Example:
%pd_no_edit(
    p_ds=LB_PREG LB_HEMA QS_STH,
    a_ds=VS PE_EXAM,
    edit=General,
    edit1=Edit319,
    edit2=Edit779
);
*/
