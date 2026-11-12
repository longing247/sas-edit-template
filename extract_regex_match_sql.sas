/* Extract day number from a cycle label using regular expressions in PROC SQL.
   Examples: C1D1 -> 1, C1D15 -> 15, C10D28 -> 28.
   Invalid patterns return a missing numeric value.
*/
proc sql;
    create table want as
    select a.*,
           case
               when prxmatch('/^C\d+D\d+$/i', strip(a.cycle)) > 0
               then input(
                   prxchange('s/^C\d+D(\d+)$/$1/i', 1, strip(a.cycle)),
                   best32.
               )
               else .
           end as day
    from have as a;
quit;
