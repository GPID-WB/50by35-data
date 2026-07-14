/* =====================================================================
02_review_raw_batch.do
50by35 pipeline — Step 1 reviewer (batch): approve or reject multiple
raw-data transactions via PRIMUS (Stata client).

Workflow:
  1. Queries PRIMUS for all pending raw-data transactions.
  2. Writes batch/02_raw_reviews.csv with decision defaulting to
     "approve". Edit the CSV to change decisions or comments before
     the script proceeds.
  3. Reads the CSV back and processes each row.

An approve/reject decision is final and cannot be changed.
Failures are logged and skipped; a summary is printed at the end.
===================================================================== */

version 18
clear
set more off

local processid 39                       // FDPRaw-data
local manifest  "batch/02_raw_reviews.csv"

* ---- auto-generate manifest from pending transactions ------------------------
di as result "=== Querying pending raw-data transactions ==="
primus query, process(`processid') overallstatus(PENDING)

if _N == 0 {
    di as result "No pending raw-data transactions — nothing to review."
    exit
}

* build manifest from query results
rename TransactionId transaction_id
rename SurveyId survey_id
gen decision = "approve"
gen comments = "raw data approved for harmonization"
keep transaction_id survey_id decision comments
export delimited using "`manifest'", replace
di as result "Wrote `manifest' with `=_N' pending transaction(s)."
di as result "  Default decision: approve. Edit the CSV now if needed."
di as result "  Press any key to continue (or break to abort)."
pause on
pause
pause off

* ---- read manifest back (user may have edited it) ----------------------------
import delimited using "`manifest'", clear stringcols(_all)
local nrev = _N

forvalues i = 1/`nrev' {
    local tid_`i'      = transaction_id[`i']
    local dec_`i'      = decision[`i']
    local comments_`i' = comments[`i']
}
clear

* ---- batch loop --------------------------------------------------------------
local nok   = 0
local nfail = 0

forvalues i = 1/`nrev' {
    local tid  "`tid_`i''"
    local dec  = strlower(strtrim("`dec_`i''"))
    local comm "`comments_`i''"
    if `"`comm'"' == "" local comm "`dec' by batch review"

    di as result _n "=== [`i'/`nrev'] `tid' (`dec') ==="

    if "`dec'" != "approve" & "`dec'" != "reject" {
        di as error "  SKIPPED: invalid decision '`dec'' — must be 'approve' or 'reject'"
        local ++nfail
        local fail_`nfail' "`tid' — invalid decision '`dec''"
        continue
    }

    capture noisily {
        primus download, processid(`processid') tranxid(`tid') filelist

        primus action, tranxid(`tid') processid(`processid') ///
            decision(`dec') comments(`comm')

        di as result "  `=strupper("`dec'")' D: `tid'"
    }

    if _rc == 0 {
        local ++nok
        local ok_`nok' "`tid' (`dec')"
    }
    else {
        local ++nfail
        local fail_`nfail' "`tid' — rc = `=_rc'"
    }
}

* ---- summary -----------------------------------------------------------------
di as result _n "=== Batch summary (02_review_raw) ==="
forvalues j = 1/`nok' {
    di as result "  OK:     `ok_`j''"
}
forvalues j = 1/`nfail' {
    di as error  "  FAILED: `fail_`j''"
}
if `nfail' > 0 {
    di as error "`nfail' of `nrev' reviews failed or skipped"
}
