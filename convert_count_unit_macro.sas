%macro convert_count_unit(
    data=,
    out=,
    value=,
    from=,
    to=,
    result=converted_value,
    status=conversion_status
);

/* Convert cell-count concentrations using cells/L as a common base.
   FROM= and TO= accept character variables or quoted string literals.
   Example: from=LBORRESU, to='10^9/L'.
   Unsupported units are flagged rather than converted.
*/
data &out;
    set &data;

    length &status $20 _unit $80;
    &result = .;
    &status = 'OK';

    _unit = upcase(compress(strip(&from), ' '));
    select (_unit);
        when ('/UL', 'CELL/UL', 'CELLS/UL',
              '/MM3', '/MM^3', 'CELL/MM3', 'CELLS/MM3',
              '10^6/L', '10**6/L', '10E6/L', '10*6/L')
            _from_factor = 1e6;
        when ('K/UL', '10^9/L', '10**9/L', '10E9/L', '10*9/L', 'G/L')
            _from_factor = 1e9;
        when ('10^11/L', '10**11/L', '10E11/L', '10*11/L')
            _from_factor = 1e11;
        when ('M/UL', '10^12/L', '10**12/L', '10E12/L', '10*12/L', 'T/L')
            _from_factor = 1e12;
        when ('CELLS/L', 'CELL/L', '/L')
            _from_factor = 1;
        otherwise _from_factor = .;
    end;

    _unit = upcase(compress(strip(&to), ' '));
    select (_unit);
        when ('/UL', 'CELL/UL', 'CELLS/UL',
              '/MM3', '/MM^3', 'CELL/MM3', 'CELLS/MM3',
              '10^6/L', '10**6/L', '10E6/L', '10*6/L')
            _to_factor = 1e6;
        when ('K/UL', '10^9/L', '10**9/L', '10E9/L', '10*9/L', 'G/L')
            _to_factor = 1e9;
        when ('10^11/L', '10**11/L', '10E11/L', '10*11/L')
            _to_factor = 1e11;
        when ('M/UL', '10^12/L', '10**12/L', '10E12/L', '10*12/L', 'T/L')
            _to_factor = 1e12;
        when ('CELLS/L', 'CELL/L', '/L')
            _to_factor = 1;
        otherwise _to_factor = .;
    end;

    if missing(_from_factor) then
        &status = 'INVALID_FROM';
    else if missing(_to_factor) then
        &status = 'INVALID_TO';
    else if missing(&value) then
        &status = 'MISSING_VALUE';
    else
        &result = &value * (_from_factor / _to_factor);

    drop _unit _from_factor _to_factor;
run;

%mend convert_count_unit;
