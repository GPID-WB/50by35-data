/* =====================================================================
01_upload_raw_batch.do
50by35 pipeline — Step 1 (batch): upload raw microdata for multiple
surveys via PRIMUS (Stata client).

Reads batch/01_raw_uploads.csv with columns:
  survey_id  — e.g. "COL_2023_GEIH_V01_M"
  files      — semicolon-separated paths relative to $REFUGEE_RAW_DATA
  docs       — (optional) semicolon-separated doc paths

Failures are logged and skipped; a summary is printed at the end.
===================================================================== */

version 18
clear
set more off

local rawroot : env REFUGEE_RAW_DATA
if `"`rawroot'"' == "" {
    di as error "Set REFUGEE_RAW_DATA to the raw-data root folder"
    exit 601
}

local processid 39                       // FDPRaw-data

* ---- read manifest -----------------------------------------------------------
import delimited using "batch/01_raw_uploads.csv", clear stringcols(_all)
local nsurv = _N

* store manifest in locals before clearing
forvalues i = 1/`nsurv' {
    local sid_`i'   = survey_id[`i']
    local files_`i' = files[`i']
    local docs_`i'  = docs[`i']
}
clear

* ---- batch loop --------------------------------------------------------------
local nok   = 0
local nfail = 0

forvalues i = 1/`nsurv' {
    local sid   "`sid_`i''"
    local flist "`files_`i''"
    local dlist "`docs_`i''"

    di as result _n "=== [`i'/`nsurv'] `sid' ==="

    capture noisily {
        * parse semicolon-separated file list
        local files ""
        while `"`flist'"' != "" {
            gettoken f flist : flist, parse(";")
            if `"`f'"' == ";" continue
            local f = strtrim(`"`f'"')
            local files `"`files' "`rawroot'/`f'""'
        }

        * parse docs list
        local docfiles ""
        while `"`dlist'"' != "" {
            gettoken d dlist : dlist, parse(";")
            if `"`d'"' == ";" continue
            local d = strtrim(`"`d'"')
            local docfiles `"`docfiles' "`rawroot'/`d'""'
        }

        * first file opens a new transaction
        local first 1
        foreach f of local files {
            if `first' {
                primus upload, processid(`processid') surveyid(`sid') ///
                    type(raw) folderpath(Data/Stata) infile("`f'") new
                local tranxid = r(prmTransId)
                di as result "  Opened transaction `tranxid'"
                local first 0
            }
            else {
                primus upload, processid(`processid') surveyid(`sid') ///
                    type(raw) folderpath(Data/Stata) infile("`f'") tranxid(`tranxid')
            }
        }

        foreach f of local docfiles {
            primus upload, processid(`processid') surveyid(`sid') ///
                type(raw) folderpath(Doc/Questionnaires) infile("`f'") tranxid(`tranxid')
        }

        primus action, tranxid(`tranxid') processid(`processid') ///
            decision(confirm) comments(raw data ready for review)

        di as result "  Confirmed: `sid'"
    }

    if _rc == 0 {
        local ++nok
        local ok_`nok' "`sid' (transaction `tranxid')"
    }
    else {
        local ++nfail
        local fail_`nfail' "`sid' — rc = `=_rc'"
    }
}

* ---- summary -----------------------------------------------------------------
di as result _n "=== Batch summary (01_upload_raw) ==="
forvalues j = 1/`nok' {
    di as result "  OK:     `ok_`j''"
}
forvalues j = 1/`nfail' {
    di as error  "  FAILED: `fail_`j''"
}
if `nfail' > 0 {
    di as error "`nfail' of `nsurv' uploads failed"
}
