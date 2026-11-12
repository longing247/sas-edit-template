/* Example 1: Extract numeric day from cycle labels in PROC SQL.
   C1D1 -> 1, C1D15 -> 15, C10D28 -> 28.
   Nonmatching labels produce a missing numeric value.
*/
proc sql;
    create table want_day as
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

/* Example 2: Join fields from dataset_b using subject and position.
   dataset_a.description: '2: something' -> position 2.
   dataset_b.pos is numeric.
   LEFT JOIN preserves rows from dataset_a without a match.
   Requires a unique (subject, pos) combination in dataset_b to avoid
   multiplying rows. If description may not start with a number followed
   by a colon, the PRXMATCH check prevents invalid numeric conversion.
*/
proc sql;
    create table want_join as
    select a.*,
           b.result
    from dataset_a as a
    left join dataset_b as b
        on a.subject = b.subject
       and case
               when prxmatch('/^\s*\d+\s*:/', a.description) > 0
               then input(strip(scan(a.description, 1, ':')), best32.)
               else .
           end = b.pos;
quit;
