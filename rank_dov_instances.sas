/* Rank scheduled DOV visits first, then unscheduled visits by datetime.
   Input: DOV (subject, DOV, datetime).
   Adjust the scheduled visit array to match the study protocol.
*/
proc sort data=dov out=_dov_chronological;
    by subject datetime;
run;

data dov_ranked;
    set _dov_chronological;
    by subject;

    array dov_order[4] $12 _temporary_ ('SCR', 'D1', 'D48', 'EOT');
    retain i;

    if first.subject then i = dim(dov_order);
    dov_rank = .;

    do j = 1 to dim(dov_order);
        if upcase(strip(DOV)) = dov_order[j] then do;
            dov_rank = j;
            leave;
        end;
    end;

    if upcase(strip(DOV)) =: 'UNSCHEDULED' then do;
        i + 1;
        dov_rank = i;
    end;

    /* Unknown DOV values retain missing rank; review before final use. */
    if missing(dov_rank) then
        put 'WARNING: Unrecognized DOV: ' subject= DOV=;

    drop i j;
run;

proc sort data=dov_ranked;
    by subject dov_rank datetime;
run;
