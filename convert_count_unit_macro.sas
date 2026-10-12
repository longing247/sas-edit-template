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

/*
  Convert multiple numeric count variables in one DATA step.
  VALUES=, FROM_UNITS=, TO_UNITS= and RESULTS= must each contain
  the same number of variable names, in corresponding order.
  FROM_UNITS= and TO_UNITS= must refer to character variables.
  Source and target unit aliases match %convert_count_unit.
*/
%macro convert_count_array(
    data=,
    out=,
    values=,
    from_units=,
    to_units=,
    results=
);

data &out;
    set &data;

    array _cc_values[*] &values;
    array _cc_from[*] $ &from_units;
    array _cc_to[*] $ &to_units;
    array _cc_results[*] &results;

    length _cc_unit $80;

    if dim(_cc_values) ne dim(_cc_from) or
       dim(_cc_values) ne dim(_cc_to) or
       dim(_cc_values) ne dim(_cc_results) then do;
        putlog 'ERROR: Conversion arrays must have equal dimensions.';
        stop;
    end;

    do _cc_i = 1 to dim(_cc_values);
        _cc_from_factor = .;
        _cc_to_factor = .;
        _cc_results[_cc_i] = .;

        _cc_unit = upcase(compress(strip(_cc_from[_cc_i]), ' '));
        select (_cc_unit);
            when ('/UL', 'CELL/UL', 'CELLS/UL',
                  '/MM3', '/MM^3', 'CELL/MM3', 'CELLS/MM3',
                  '10^6/L', '10**6/L', '10E6/L', '10*6/L')
                _cc_from_factor = 1e6;
            when ('K/UL', '10^9/L', '10**9/L', '10E9/L', '10*9/L', 'G/L')
                _cc_from_factor = 1e9;
            when ('10^11/L', '10**11/L', '10E11/L', '10*11/L')
                _cc_from_factor = 1e11;
            when ('M/UL', '10^12/L', '10**12/L', '10E12/L', '10*12/L', 'T/L')
                _cc_from_factor = 1e12;
            when ('CELLS/L', 'CELL/L', '/L')
                _cc_from_factor = 1;
            otherwise;
        end;

        _cc_unit = upcase(compress(strip(_cc_to[_cc_i]), ' '));
        select (_cc_unit);
            when ('/UL', 'CELL/UL', 'CELLS/UL',
                  '/MM3', '/MM^3', 'CELL/MM3', 'CELLS/MM3',
                  '10^6/L', '10**6/L', '10E6/L', '10*6/L')
                _cc_to_factor = 1e6;
            when ('K/UL', '10^9/L', '10**9/L', '10E9/L', '10*9/L', 'G/L')
                _cc_to_factor = 1e9;
            when ('10^11/L', '10**11/L', '10E11/L', '10*11/L')
                _cc_to_factor = 1e11;
            when ('M/UL', '10^12/L', '10**12/L', '10E12/L', '10*12/L', 'T/L')
                _cc_to_factor = 1e12;
            when ('CELLS/L', 'CELL/L', '/L')
                _cc_to_factor = 1;
            otherwise;
        end;

        if not missing(_cc_values[_cc_i]) and
           not missing(_cc_from_factor) and
           not missing(_cc_to_factor) then
            _cc_results[_cc_i] =
                _cc_values[_cc_i] * (_cc_from_factor / _cc_to_factor);
    end;

    drop _cc_i _cc_unit _cc_from_factor _cc_to_factor;
run;

%mend convert_count_array;

/*
Example (wide-format LB_CHEM):

%convert_count_array(
    data=lb_chem,
    out=lb_chem_converted,
    values=WBC RBC PLT,
    from_units=WBC_UNIT RBC_UNIT PLT_UNIT,
    to_units=WBC_STD_UNIT RBC_STD_UNIT PLT_STD_UNIT,
    results=WBC_STD RBC_STD PLT_STD
);
*/
