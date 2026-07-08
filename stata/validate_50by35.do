/* =====================================================================
validate_50by35.do
Validate the dataset in memory against the 50by35 schema
(see chapters/05-schema.qmd). Any violation stops with an error,
preventing upload of a non-conforming file.

Usage:  use "<harmonized file>.dta", clear
        do "Stata/validate_50by35.do"
===================================================================== */

* ---- mandatory variables present -----------------------------------------
foreach v in code year hhid pid welfare welfare_type welfare_self ///
             weight camp urban {
    capture confirm variable `v'
    if _rc {
        di as error "SCHEMA ERROR: mandatory variable `v' is missing"
        exit 459
    }
}

* ---- identifier types and uniqueness --------------------------------------
capture confirm string variable code hhid pid
if _rc {
    di as error "SCHEMA ERROR: code, hhid and pid must be strings"
    exit 459
}
capture assert strlen(code)==3
if _rc {
    di as error "SCHEMA ERROR: code must be a 3-letter code"
    exit 459
}
capture isid hhid pid
if _rc {
    di as error "SCHEMA ERROR: hhid + pid do not uniquely identify observations"
    exit 459
}

* ---- missing values in mandatory variables (camp/urban may be missing) ----
foreach v in year welfare welfare_type welfare_self weight {
    capture assert !missing(`v')
    if _rc {
        di as error "SCHEMA ERROR: missing values in mandatory variable `v'"
        exit 459
    }
}
capture assert hhid != "" & pid != ""
if _rc {
    di as error "SCHEMA ERROR: empty hhid or pid"
    exit 459
}

* ---- value ranges ----------------------------------------------------------
capture assert inrange(year, 1990, 2035)
if _rc {
    di as error "SCHEMA ERROR: year outside 1990-2035"
    exit 459
}
capture assert welfare > 0
if _rc {
    di as error "SCHEMA ERROR: welfare must be strictly positive"
    exit 459
}
capture assert weight > 0
if _rc {
    di as error "SCHEMA ERROR: weight must be strictly positive"
    exit 459
}
capture assert welfare_self >= 0
if _rc {
    di as error "SCHEMA ERROR: welfare_self must be non-negative"
    exit 459
}
capture assert welfare_self <= welfare
if _rc {
    di as error "SCHEMA ERROR: welfare_self greater than welfare"
    exit 459
}
capture assert inrange(welfare_type, 1, 3)
if _rc {
    di as error "SCHEMA ERROR: welfare_type outside 1-3"
    exit 459
}
foreach v in camp urban {
    capture assert inlist(`v', 0, 1) | missing(`v')
    if _rc {
        di as error "SCHEMA ERROR: `v' must be 0/1 or missing"
        exit 459
    }
}

* ---- optional variables, when present --------------------------------------
capture confirm variable hhsize
if !_rc {
    capture assert hhsize >= 1 | missing(hhsize)
    if _rc {
        di as error "SCHEMA ERROR: hhsize below 1"
        exit 459
    }
    * hhsize vs. the number of person records per hhid: a mismatch is
    * common when the individual roster is incomplete (members without
    * person records), so this is a WARNING, not an error. hhsize keeps
    * the survey's household size — the welfare denominator.
    tempvar npid
    bysort hhid: gen `npid' = _N
    qui count if hhsize != `npid' & !missing(hhsize)
    if r(N) > 0 {
        di as txt "SCHEMA WARNING: hhsize differs from person-record count per hhid for " r(N) " obs (incomplete roster?)"
    }
    drop `npid'
}
capture confirm variable age
if !_rc {
    capture assert inrange(age, 0, 120) | missing(age)
    if _rc {
        di as error "SCHEMA ERROR: age outside 0-120"
        exit 459
    }
}
capture confirm variable male
if !_rc {
    capture assert inlist(male, 0, 1) | missing(male)
    if _rc {
        di as error "SCHEMA ERROR: male must be 0/1 or missing"
        exit 459
    }
}
capture confirm variable educat4
if !_rc {
    capture assert inrange(educat4, 1, 4) | missing(educat4)
    if _rc {
        di as error "SCHEMA ERROR: educat4 outside 1-4"
        exit 459
    }
}
capture confirm variable empstat
if !_rc {
    capture assert inrange(empstat, 1, 4) | missing(empstat)
    if _rc {
        di as error "SCHEMA ERROR: empstat outside 1-4"
        exit 459
    }
}

di as result "50by35 schema validation PASSED (`=_N' observations)"
