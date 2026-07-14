/* =====================================================================
03_upload_harmonized_batch.do
50by35 pipeline — Step 3 (batch): validate, build indicator XML, and
upload harmonized files for multiple surveys via PRIMUS (Stata client).

Workflow:
  1. Scans data/processed/ for *_WELF.dta files and matches each to
     a Stata/*_WELF.do harmonization script.
  2. Writes batch/03_harmonized_uploads.csv with the discovered
     surveys. Edit the CSV to remove rows, add cpi/ppp overrides,
     etc. before the script proceeds.
  3. Reads the CSV back and processes each row.

Failures are logged and skipped; a summary is printed at the end.
===================================================================== */

version 18
clear
set more off

local outdir : env FIFTYBY35_PROCESSED
if `"`outdir'"' == "" local outdir "~/Github/50by35-data/data/processed"

local processid 40                       // FDP-harmonized-data
local zline     3.00                     // placeholder poverty line, $/day 2021 PPP
local manifest  "batch/03_harmonized_uploads.csv"

* ---- auto-generate manifest from processed .dta files ------------------------
local dtafiles : dir "`outdir'" files "*_WELF.dta"
local nsurv : word count `dtafiles'

if `nsurv' == 0 {
    di as error "No *_WELF.dta files found in `outdir'"
    exit 601
}

clear
set obs `nsurv'
gen str200 survey_id    = ""
gen str200 harm_script  = ""
gen str20  cpi_override = ""
gen str20  ppp_override = ""

local i = 0
foreach f of local dtafiles {
    local ++i
    * strip _WELF.dta to get survey_id
    local sid = subinstr("`f'", "_WELF.dta", "", 1)
    replace survey_id   = "`sid'"                              in `i'
    replace harm_script = "Stata/`sid'_WELF.do"                in `i'

    * warn if harmonization script doesn't exist
    capture confirm file "Stata/`sid'_WELF.do"
    if _rc {
        di as error "  WARNING: harmonization script not found for `sid'"
    }
}

export delimited using "`manifest'", replace
di as result "Wrote `manifest' with `nsurv' survey(s) found in `outdir'."
di as result "  Edit the CSV now to remove surveys, add overrides, etc."
di as result "  Press any key to continue (or break to abort)."
pause on
pause
pause off

* ---- read manifest back (user may have edited it) ----------------------------
import delimited using "`manifest'", clear stringcols(_all)
local nsurv = _N

forvalues i = 1/`nsurv' {
    local sid_`i'     = survey_id[`i']
    local hs_`i'      = harm_script[`i']
    local cpiov_`i'   = cpi_override[`i']
    local pppov_`i'   = ppp_override[`i']
}
clear

* ---- batch loop --------------------------------------------------------------
local nok   = 0
local nfail = 0

forvalues i = 1/`nsurv' {
    local sid        "`sid_`i''"
    local harmscript "`hs_`i''"
    local cpi_override "`cpiov_`i''"
    local ppp_override "`pppov_`i''"

    * treat blank overrides as missing
    if `"`cpi_override'"' == "" local cpi_override .
    if `"`ppp_override'"' == "" local ppp_override .

    local dtafile "`outdir'/`sid'_WELF.dta"

    di as result _n "=== [`i'/`nsurv'] `sid' ==="

    capture noisily {
        * ---- validation -------------------------------------------------------
        use "`dtafile'", clear
        do "Stata/validate_50by35.do"

        local ccode = code[1]
        local year  = year[1]

        * ---- CPI / PPP --------------------------------------------------------
        local cpimethod "EmbeddedCPI"
        preserve
        if mi(`cpi_override') {
            pip tables, table(cpi) ppp_year(2021) clear
            capture confirm variable cpi
            if !_rc local cpivar cpi
            else local cpivar value
            capture confirm variable data_level
            if !_rc keep if data_level=="national"
            keep if country_code=="`ccode'"
            drop if mi(`cpivar')

            * check for exact match
            count if year==`year'
            if r(N) == 1 {
                qui sum `cpivar' if year==`year'
                local cpival = r(mean)
            }
            else {
                * fallback: interpolate or nearest year
                if _N == 0 {
                    di as error "PIP has no CPI data at all for `ccode'"
                    exit 498
                }
                gen _yr = real(string(year))

                * find bracketing years
                qui sum _yr if _yr <= `year'
                local lo_yr = r(max)
                qui sum _yr if _yr >= `year'
                local hi_yr = r(min)

                if !mi(`lo_yr') & !mi(`hi_yr') & `lo_yr' != `hi_yr' {
                    * linear interpolation
                    qui sum `cpivar' if _yr == `lo_yr'
                    local lo_cpi = r(mean)
                    qui sum `cpivar' if _yr == `hi_yr'
                    local hi_cpi = r(mean)
                    local frac = (`year' - `lo_yr') / (`hi_yr' - `lo_yr')
                    local cpival = `lo_cpi' + `frac' * (`hi_cpi' - `lo_cpi')
                    local cpimethod "Interpolated(CPI_`lo_yr'=`: di %9.6f `lo_cpi'',CPI_`hi_yr'=`: di %9.6f `hi_cpi'')"
                    di as result "  CPI fallback: `cpimethod'"
                }
                else {
                    * nearest year
                    gen _dist = abs(_yr - `year')
                    qui sum _dist
                    qui sum `cpivar' if _dist == r(min)
                    local cpival = r(mean)
                    qui sum _yr if _dist == r(min)
                    local near_yr = r(mean)
                    local cpimethod "NearestYear(CPI_`=int(`near_yr')'=`: di %9.6f `cpival'')"
                    di as result "  CPI fallback: `cpimethod'"
                }
            }
        }
        else {
            local cpival = `cpi_override'
            local cpimethod "ManualOverride"
        }

        if mi(`ppp_override') {
            pip tables, table(ppp) ppp_year(2021) clear
            capture confirm variable ppp
            if !_rc local pppvar ppp
            else local pppvar value
            capture confirm variable data_level
            if !_rc keep if data_level=="national"
            keep if country_code=="`ccode'"
            if _N < 1 | mi(`pppvar'[1]) {
                di as error "PIP has no 2021 PPP for `ccode' — set ppp_override in manifest"
                exit 498
            }
            local pppval = `pppvar'[1]
        }
        else local pppval = `ppp_override'
        restore

        di as result "  CPI(`ccode',`year') = `cpival'   PPP2021(`ccode') = `pppval'"

        * ---- indicators -------------------------------------------------------
        gen byte _sr = (welfare_self/365/`cpival'/`pppval') >= `zline'
        qui sum _sr [aw=weight]
        local sr : di %9.6f r(mean)
        gen byte _poor = (welfare/365/`cpival'/`pppval') < `zline'
        qui sum _poor [aw=weight]
        local hc : di %9.6f r(mean)
        qui sum welfare [aw=weight]
        local meanlcu : di %14.2f r(mean)
        qui sum welfare_self [aw=weight]
        local meanlcuself : di %14.2f r(mean)
        local nrecs = _N
        drop _sr _poor

        di as result "  Self-reliance share (z=$`zline'/day 2021 PPP): `sr'"

        * ---- write indicator XML -----------------------------------------------
        local xmlfile "`outdir'/`sid'.xml"
        tempname fh
        file open `fh' using "`xmlfile'", write replace

        file write `fh' `"<PRIMUS_ANALYSIS>"' _n
        file write `fh' `"  <Request>"' _n
        file write `fh' `"    <RequestKey><![CDATA[]]></RequestKey>"' _n
        file write `fh' `"    <welfare>welfare_self</welfare>"' _n
        file write `fh' `"    <weight>weight</weight>"' _n
        file write `fh' `"    <By></By>"' _n
        file write `fh' `"    <N_By_Group>1</N_By_Group>"' _n
        file write `fh' `"    <nParamSets>2</nParamSets>"' _n
        file write `fh' `"    <![CDATA["' _n
        file write `fh' `"key;value"' _n
        file write `fh' `"APP_ID;Stata"' _n
        file write `fh' `"DATETIME;`c(current_date)' `c(current_time)'"' _n
        file write `fh' `"COUNTRY_CODE;`ccode'"' _n
        file write `fh' `"FILENAME;`sid'_WELF.dta"' _n
        file write `fh' `"DATA_YEAR;`year'"' _n
        file write `fh' `"REF_YEAR;`year'"' _n
        file write `fh' `"PPP_YEAR;2021"' _n
        file write `fh' `"    ]]>"' _n
        file write `fh' `"  </Request>"' _n
        file write `fh' `"  <Result>"' _n
        file write `fh' `"    <Welfare var="welfare_self" weight="weight">"' _n
        file write `fh' `"      <ByGroup byCondition="none">"' _n
        file write `fh' `"        <DATASUMMARY>"' _n
        file write `fh' `"          <![CDATA["' _n
        file write `fh' `"key;value"' _n
        file write `fh' `"nRecs;`nrecs'"' _n
        file write `fh' `"Mean_LCU_welfare;`=trim("`meanlcu'")'"' _n
        file write `fh' `"Mean_LCU_welfare_self;`=trim("`meanlcuself'")'"' _n
        file write `fh' `"          ]]>"' _n
        file write `fh' `"        </DATASUMMARY>"' _n
        file write `fh' `"        <CALCULATION>"' _n
        file write `fh' `"          <![CDATA["' _n
        file write `fh' `"key;value"' _n
        file write `fh' `"Indicator;PovertyHeadcount"' _n
        file write `fh' `"Variable;welfare"' _n
        file write `fh' `"PovertyLine;`zline'"' _n
        file write `fh' `"Method;`cpimethod'"' _n
        file write `fh' `"CPIValue;`cpival'"' _n
        file write `fh' `"PPPValue;`pppval'"' _n
        file write `fh' `"Value;`=trim("`hc'")'"' _n
        file write `fh' `"          ]]>"' _n
        file write `fh' `"        </CALCULATION>"' _n
        file write `fh' `"        <CALCULATION>"' _n
        file write `fh' `"          <![CDATA["' _n
        file write `fh' `"key;value"' _n
        file write `fh' `"Indicator;SelfRelianceShare"' _n
        file write `fh' `"Variable;welfare_self"' _n
        file write `fh' `"PovertyLine;`zline'"' _n
        file write `fh' `"Method;`cpimethod'"' _n
        file write `fh' `"CPIValue;`cpival'"' _n
        file write `fh' `"PPPValue;`pppval'"' _n
        file write `fh' `"Value;`=trim("`sr'")'"' _n
        file write `fh' `"          ]]>"' _n
        file write `fh' `"        </CALCULATION>"' _n
        file write `fh' `"      </ByGroup>"' _n
        file write `fh' `"    </Welfare>"' _n
        file write `fh' `"  </Result>"' _n
        file write `fh' `"  <LOG_DETAIL>"' _n
        file write `fh' `"    <![CDATA["' _n
        file write `fh' `"50by35 self-reliance indicator for `sid'."' _n
        file write `fh' `"welfare_self / 365 / CPI(`ccode',`year')=`cpival' / PPP2021(`ccode')=`pppval' >= z=`zline' (placeholder, pending confirmation from the 50by35 methodology team)."' _n
        file write `fh' `"PovertyHeadcount (welfare, same z): `=trim("`hc'")'"' _n
        file write `fh' `"SelfRelianceShare (welfare_self): `=trim("`sr'")'"' _n
        file write `fh' `"    ]]>"' _n
        file write `fh' `"  </LOG_DETAIL>"' _n
        file write `fh' `"</PRIMUS_ANALYSIS>"' _n
        file close `fh'
        di as result "  Wrote `xmlfile'"

        * ---- upload -----------------------------------------------------------
        primus upload, processid(`processid') surveyid(`sid') ///
            type(harmonized) infile("`xmlfile'") xmlbl new
        local tranxid = r(prmTransId)
        di as result "  Opened transaction `tranxid'"

        primus upload, processid(`processid') surveyid(`sid') ///
            type(harmonized) folderpath(Data/Harmonized) infile("`dtafile'") tranxid(`tranxid')

        primus upload, processid(`processid') surveyid(`sid') ///
            type(harmonized) folderpath(Programs) infile("`harmscript'") tranxid(`tranxid')

        primus action, tranxid(`tranxid') processid(`processid') ///
            decision(confirm) comments(harmonized data ready for review)

        di as result "  Confirmed: `sid'"
    }

    if _rc == 0 {
        local ++nok
        local ok_`nok' "`sid' (transaction `tranxid') SR=`=trim("`sr'")' HC=`=trim("`hc'")'"
    }
    else {
        local ++nfail
        local fail_`nfail' "`sid' — rc = `=_rc'"
    }
}

* ---- summary -----------------------------------------------------------------
di as result _n "=== Batch summary (03_upload_harmonized) ==="
forvalues j = 1/`nok' {
    di as result "  OK:     `ok_`j''"
}
forvalues j = 1/`nfail' {
    di as error  "  FAILED: `fail_`j''"
}
if `nfail' > 0 {
    di as error "`nfail' of `nsurv' uploads failed"
}
