%macro file_iso_timestamp(
    filepath,
    date_type=MODIFIED,
    format=DATETIME,
    timezone=America/New_York,
    out=iso_timestamp,
    safe=Y
);
    %local _type _format _safe;
    %let _type=%upcase(&date_type);
    %let _format=%upcase(&format);
    %let _safe=%upcase(&safe);

    %global &out;
    %let &out=;

    %if %length(%superq(filepath)) = 0 %then %do;
        %put ERROR: filepath is required.;
        %return;
    %end;
    %if &_type ne CREATED and &_type ne MODIFIED %then %do;
        %put ERROR: date_type must be CREATED or MODIFIED.;
        %return;
    %end;
    %if &_format ne DATE and &_format ne DATETIME %then %do;
        %put ERROR: format must be DATE or DATETIME.;
        %return;
    %end;
    %if &_safe ne Y and &_safe ne N %then %do;
        %put ERROR: safe must be Y or N.;
        %return;
    %end;

    data _null_;
        length path $1024 timestamp $100 iso_timestamp $32
               tz $64 sign $1;

        path = symget('filepath');
        tz = symget('timezone');

        rc = filename('srcfile', path);
        if rc ne 0 then do;
            putlog 'ERROR: Cannot assign fileref: ' path;
            stop;
        end;

        fid = fopen('srcfile', 'I');
        if fid <= 0 then do;
            putlog 'ERROR: Cannot open file: ' path;
            rc = filename('srcfile');
            stop;
        end;

        /* Attribute names should be verified on the target Windows SAS host. */
        if "&_type" = "CREATED" then
            timestamp = finfo(fid, 'Create Time');
        else
            timestamp = finfo(fid, 'Last Modified');

        if missing(timestamp) then
            putlog 'ERROR: Requested file timestamp attribute is unavailable.';
        else do;
            dt = input(timestamp, ?? anydtdtm40.);
            if missing(dt) then
                putlog 'ERROR: Cannot parse file timestamp: ' timestamp;
            else do;
                if "&_format" = "DATE" then
                    iso_timestamp = put(datepart(dt), e8601da10.);
                else do;
                    /*
                     * Assumes FINFO returns local datetime in the requested
                     * timezone. This is NOT a timezone conversion.
                     * Validate TZ offset handling on the target SAS host,
                     * especially near DST fall-back.
                     */
                    offset = tzoneoff(tz, dt);
                    if missing(offset) then
                        putlog 'ERROR: Cannot determine timezone offset.';
                    else do;
                        if offset < 0 then sign = '-';
                        else sign = '+';
                        hh = floor(abs(offset) / 3600);
                        mm = floor(mod(abs(offset), 3600) / 60);
                        iso_timestamp = cats(
                            put(datepart(dt), e8601da10.), 'T',
                            put(timepart(dt), time8.), sign,
                            put(hh, z2.), ':', put(mm, z2.)
                        );
                        if "&_safe" = "Y" then
                            iso_timestamp = translate(iso_timestamp, '-', ':');
                    end;
                end;
                if not missing(iso_timestamp) then
                    call symputx("&out", strip(iso_timestamp), 'G');
            end;
        end;

        rc = fclose(fid);
        rc = filename('srcfile');
    run;

    %if %length(%superq(&out)) > 0 %then %do;
        %put NOTE: &out = %superq(&out);
    %end;
%mend file_iso_timestamp;
