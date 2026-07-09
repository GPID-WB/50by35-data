* Shared Stata utility script
* Add helper programs and globals used across multiple chapters here.

* ---- get_raw_data: load a raw microdata file into memory ------------------
* Used by the harmonization scripts (Stata/*_FDP_WELF.do) to fetch a raw
* file either from a local folder (as pointed to by REFUGEE_RAW_DATA) or
* from datalibweb's FDPRAW collection (see chapters/04-access.qmd). The
* datalibweb path requires the datalibweb Stata package and a registered
* token.
*
* Syntax: get_raw_data, source(local|datalibweb) localpath(string) ///
*             country(string) years(string) surveyid(string) filename(string)
capture program drop get_raw_data
program define get_raw_data
    syntax, source(string) localpath(string) country(string) years(string) ///
        surveyid(string) filename(string)

    if "`source'" == "local" {
        use `"`localpath'"', clear
    }
    else if "`source'" == "datalibweb" {
        datalibweb, country(`country') years(`years') type(FDPRAW) ///
            surveyid(`surveyid') filename(`filename') clear
    }
    else {
        di as error "get_raw_data: source must be local or datalibweb"
        exit 198
    }
end

* ---- get_raw_data_path: same lookup, returned as a file path --------------
* For the `using` side of a merge, which needs a file on disk. "local"
* returns localpath as-is; "datalibweb" downloads the file into memory
* and saves it to a tempfile, leaving the dataset already in memory
* untouched.
*
* Syntax: get_raw_data_path, source(local|datalibweb) localpath(string) ///
*             country(string) years(string) surveyid(string) filename(string)
* Returns: r(path)
capture program drop get_raw_data_path
program define get_raw_data_path, rclass
    syntax, source(string) localpath(string) country(string) years(string) ///
        surveyid(string) filename(string)

    if "`source'" == "local" {
        return local path `"`localpath'"'
    }
    else if "`source'" == "datalibweb" {
        preserve
        datalibweb, country(`country') years(`years') type(FDPRAW) ///
            surveyid(`surveyid') filename(`filename') clear
        tempfile tf
        save `"`tf'"'
        restore
        return local path `"`tf'"'
    }
    else {
        di as error "get_raw_data_path: source must be local or datalibweb"
        exit 198
    }
end
