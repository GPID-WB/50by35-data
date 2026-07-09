/* =====================================================================
03_upload_harmonized.do
50by35 pipeline — Step 3: validate, build the indicator XML, and upload
a harmonized file via PRIMUS (Stata client).

The transaction starts from an indicator XML (uploaded with the xmlbl
flag) that records the 50by35 self-reliance indicator for the reviewer
to approve; the data and harmonization scripts are then attached to the
same transaction.

CPI and 2021 PPP conversion factors come from the World Bank PIP API
via the pip Stata package (ssc install pip). z = $3.00/day 2021 PPP.

Requires: primus Stata package + registered token; pip package.
Run from the repository root. Process id 40 (FDP-harmonized-data) is
illustrative — verify with: primus download, meta
===================================================================== */

version 18
clear
set more off

local outdir : env FIFTYBY35_PROCESSED
if `"`outdir'"' == "" local outdir "~/Github/50by35-data/data/processed"

* ---- parameters: uncomment ONE survey block ------------------------------
local processid 40                       // FDP-harmonized-data
local zline     3.00                     // placeholder poverty line, $/day 2021 PPP —
                                          // pending confirmation from the 50by35 methodology team

local surveyid  "TCD_2022_EHCVM_V01_M_V01_A_FDP"
local harmscript "Stata/TCD_2022_EHCVM_V01_M_V01_A_FDP_WELF.do"

*local surveyid  "COL_2023_GEIH_V01_M_V01_A_FDP"
*local harmscript "Stata/COL_2023_GEIH_V01_M_V01_A_FDP_WELF.do"

*local surveyid  "UGA_2018_RHS_V01_M_V01_A_FDP"
*local harmscript "Stata/UGA_2018_RHS_V01_M_V01_A_FDP_WELF.do"

local dtafile "`outdir'/`surveyid'_WELF.dta"

* PIP's CPI is only populated for country-years with a PIP survey. For
* surveys outside PIP (e.g. UGA_2018_RHS), set cpi_override to the ratio
* CPI(survey year)/CPI(2021) from the national CPI series (e.g. WDI
* FP.CPI.TOTL); the Uganda 2018 value from the report package is
* 171.14172/185.89218 = 0.92066.
local cpi_override .
local ppp_override .

* ---- validation: any schema violation stops before upload -----------------
use "`dtafile'", clear
do "Stata/validate_50by35.do"

local ccode = code[1]
local year  = year[1]

* ---- CPI / PPP conversion factors from PIP, pinned to the 2021 framework ---
* CPI: normalized to 1 in 2021, aligned to the survey fieldwork period.
* PPP: ICP 2021 conversion factor (LCU per 2021 international $).
preserve
if mi(`cpi_override') {
    pip tables, table(cpi) ppp_year(2021) clear
    capture confirm variable cpi
    if !_rc local cpivar cpi
    else local cpivar value
    capture confirm variable data_level
    if !_rc keep if data_level=="national"
    keep if country_code=="`ccode'" & year==`year'
    if _N != 1 | mi(`cpivar'[1]) {
        di as error "PIP has no CPI for `ccode' `year' (survey not in PIP?) — " ///
            "set cpi_override to CPI(`year')/CPI(2021) from the national CPI series"
        exit 498
    }
    local cpival = `cpivar'[1]
}
else local cpival = `cpi_override'

if mi(`ppp_override') {
    pip tables, table(ppp) ppp_year(2021) clear
    capture confirm variable ppp
    if !_rc local pppvar ppp
    else local pppvar value
    capture confirm variable data_level
    if !_rc keep if data_level=="national"
    keep if country_code=="`ccode'"
    if _N < 1 | mi(`pppvar'[1]) {
        di as error "PIP has no 2021 PPP for `ccode' — set ppp_override"
        exit 498
    }
    local pppval = `pppvar'[1]
}
else local pppval = `ppp_override'
restore

di as result "CPI(`ccode',`year') = `cpival'   PPP2021(`ccode') = `pppval'"

* ---- 50by35 self-reliance indicator ----------------------------------------
* SR = weighted share with welfare_self/365/CPI/PPP >= z
gen byte _sr = (welfare_self/365/`cpival'/`pppval') >= `zline'
qui sum _sr [aw=weight]
local sr : di %9.6f r(mean)
gen byte _poor = (welfare/365/`cpival'/`pppval') < `zline'
qui sum _poor [aw=weight]
local hc : di %9.6f r(mean)
qui sum welfare [aw=weight]
local meanlcu : di %14.2f r(mean)
local nrecs = _N
drop _sr _poor

di as result "Self-reliance share (z=$`zline'/day 2021 PPP): `sr'"

* ---- write the indicator XML ------------------------------------------------
local xmlfile "`outdir'/`surveyid'.xml"
tempname fh
file open `fh' using "`xmlfile'", write replace
file write `fh' `"<PRIMUS_ANALYSIS>"' _n
file write `fh' `"  <Request>"' _n
file write `fh' `"    <welfare>welfare,welfare_self</welfare>"' _n
file write `fh' `"    <weight>weight</weight>"' _n
file write `fh' `"    <![CDATA[APP_ID=Stata"' _n
file write `fh' `"DATETIME=`c(current_date)' `c(current_time)'"' _n
file write `fh' `"COUNTRY_CODE=`ccode'"' _n
file write `fh' `"FILENAME=`surveyid'_WELF.dta"' _n
file write `fh' `"DATA_YEAR=`year'"' _n
file write `fh' `"REF_YEAR=`year'"' _n
file write `fh' `"PPP_YEAR=2021]]>"' _n
file write `fh' `"  </Request>"' _n
file write `fh' `"  <Result>"' _n
file write `fh' `"    <ByGroup byCondition="none">"' _n
file write `fh' `"      <DATASUMMARY nRecs="`nrecs'" Mean_LCU="`=trim("`meanlcu'")'" />"' _n
file write `fh' `"      <CALCULATION povertyLine="`zline'" method="EmbeddedCPI" CPIValue="`cpival'" PPPValue="`pppval'" Headcount="`=trim("`hc'")'" SelfReliantShare="`=trim("`sr'")'" />"' _n
file write `fh' `"    </ByGroup>"' _n
file write `fh' `"  </Result>"' _n
file write `fh' `"</PRIMUS_ANALYSIS>"' _n
file close `fh'
di as result "Wrote `xmlfile'"

* ---- upload: XML opens the transaction, then attach data + programs --------
primus upload, processid(`processid') surveyid(`surveyid') ///
    type(harmonized) infile("`xmlfile'") xmlbl new
local tranxid = r(prmTransId)
di as result "Opened transaction `tranxid'"

primus upload, processid(`processid') surveyid(`surveyid') ///
    type(harmonized) folderpath(Data/Harmonized) infile("`dtafile'") tranxid(`tranxid')

* harmonization code makes the upload reproducible from source
primus upload, processid(`processid') surveyid(`surveyid') ///
    type(harmonized) folderpath(Programs) infile("`harmscript'") tranxid(`tranxid')

* ---- confirm the draft so it becomes visible to approvers ------------------
primus action, tranxid(`tranxid') processid(`processid') ///
    decision(confirm) comments(harmonized data ready for review)

di as result "Harmonized upload confirmed: `surveyid' (transaction `tranxid')"
