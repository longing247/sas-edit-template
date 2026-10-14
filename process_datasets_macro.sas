/*
  Process each dataset in a space-separated list, then concatenate the
  processed outputs into one dataset.

  Example:
    %process_datasets(
        datasets=work.A work.B work.C,
        out=work.combined
    );

  Replace the placeholder processing logic with your own transformations.
  Output datasets are named <input-member>_processed in the same library.
*/
%macro process_datasets(datasets=, out=);
    %local i n ds processed_list;

    %let n = %sysfunc(countw(%superq(datasets), %str( )));
    %let processed_list=;

    %if &n = 0 %then %do;
        %put ERROR: DATASETS= must contain at least one dataset.;
        %return;
    %end;

    %if %superq(out) = %then %do;
        %put ERROR: OUT= must specify an output dataset.;
        %return;
    %end;

    %do i = 1 %to &n;
        %let ds = %scan(%superq(datasets), &i, %str( ));

        /* Process one dataset. Customize this DATA step as needed. */
        data &ds._processed;
            set &ds;
            /* Your processing logic here */
        run;

        %if &syserr > 4 %then %do;
            %put ERROR: Processing failed for &ds..;
            %return;
        %end;

        %let processed_list = &processed_list &ds._processed;
    %end;

    /* Vertically concatenate all successfully processed datasets. */
    data &out;
        set &processed_list;
    run;
%mend process_datasets;
