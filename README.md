# sas-edit

Small SAS examples for common data-editing and validation tasks.

## Current example

`date_more_than_7_days.sas` identifies observations where `date` is more than 7 days later than the earliest date within each `subject + visit` group.

The program includes two implementations:

1. DATA step approach
2. PROC SQL approach

Both output only:

- `subject`
- `visit`
- `date`

for records that fall more than 7 days after the group-level earliest date.

## Assumption

`date` is a SAS date value. If it is a SAS datetime value, convert it with `datepart()` or compare using seconds instead of days.
