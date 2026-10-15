/*
 * Validate each status variable independently (without transposing).
 * Rule 1: consecutive 'N' values within SUBJECT, both input lists.
 * Rule 2: strictly >40% 'N' among all rows, procedure list only.
 * Inputs: CPDRV.x<dataset>; ordered by SUBJECT InstanceName FolderSeq.
 * SUBJECT is assumed character; EDIT must be an assigned output libref.
 */
%macro pd_no_edit(p_ds=, a_ds=, edit=, edit1=, edit2=);
    %local all_ds n_all i j ds ds_prefix varlist nvars stat_var
           is_proc list1 list2;

    %let all_ds=&p_ds &a_ds;
    %let n_all=%sysfunc(countw(%superq(all_ds), %str( )));
    %let list1=;
    %let list2=;

    %if &n_all = 0 %then %do;
        %put ERROR: Both input dataset lists are empty.;
        %return;
    %end;

    %do i=1 %to &n_all;
        %let ds=%scan(%superq(all_ds), &i, %str( ));
        %let ds_prefix=%scan(&ds, 1, _);
        %let varlist=;

        %if not %sysfunc(exist(cpdrv.x&ds)) %then %do;
            %put ERROR: Missing dataset cpdrv.x&ds..;
            %return;
        %end;

        proc contents data=cpdrv.x&ds
            out=work._pd_vars(keep=name type varnum) noprint;
        run;

        proc sql noprint;
            select nliteral(name) into :varlist separated by ' '
            from work._pd_vars
            where type=2
              and prxmatch("/^&ds_prefix.STAT(_.*)?_STD$/i", strip(name)) > 0
            order by varnum;
        quit;

        %let nvars=%sysfunc(countw(%superq(varlist), %str( )));
        %if &nvars = 0 %then %do;
            %put NOTE: No matching status variables in &ds..;
        %end;
        %else %do;
            proc sort data=cpdrv.x&ds out=work._pd_sorted;
                by SUBJECT InstanceName FolderSeq;
            run;

            %let is_proc=%sysfunc(findw(%superq(p_ds), %superq(ds), %str( )));

            /* Macro expansion produces an independent LAG queue per variable. */
            %do j=1 %to &nvars;
                %let stat_var=%scan(%superq(varlist), &j, %str( ));

                data work._pd_e1_&i._&j;
                    set work._pd_sorted;
                    length source_ds $32 variable $32 value $200 rule $40;
                    /* Execute LAG on every row, never inside IF. */
                    prev_status=lag(&stat_var);
                    prev_subject=lag(SUBJECT);
                    source_ds="&ds";
                    variable=vname(&stat_var);
                    rule="CONSECUTIVE_N";

                    if SUBJECT=prev_subject
                       and upcase(strip(&stat_var))='N'
                       and upcase(strip(prev_status))='N' then do;
                        value=&stat_var;
                        output;
                    end;
                    keep source_ds SUBJECT InstanceName FolderSeq
                         variable value rule;
                run;
                %let list1=&list1 work._pd_e1_&i._&j;

                %if &is_proc > 0 %then %do;
                    proc sql;
                        create table work._pd_e2_&i._&j as
                        select "&ds" as source_ds length=32,
                               "%sysfunc(dequote(%superq(stat_var)))"
                                   as variable length=32,
                               "N_OVER_40_PERCENT" as rule length=40,
                               count(*) as total,
                               sum(upcase(strip(&stat_var))='N') as n_count,
                               calculated n_count / calculated total * 100
                                   as pct_n
                        from work._pd_sorted
                        having calculated pct_n > 40;
                    quit;
                    %let list2=&list2 work._pd_e2_&i._&j;
                %end;
            %end;
        %end;
    %end;

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
