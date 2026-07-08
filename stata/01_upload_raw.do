/* =====================================================================
01_upload_raw.do
50by35 pipeline — Step 1: upload raw microdata via PRIMUS (Stata client)

Requires: the primus Stata package (net install from
          https://github.com/worldbank/primus-stata) and a registered
          Datalibweb token (valid 30 days):
              primus register, token(<your Datalibweb token>)

The raw process id below (39, FDPRaw-data) is illustrative — verify
yours with:  primus download, meta
===================================================================== */

version 18
clear
set more off

local rawroot : env REFUGEE_RAW_DATA
if `"`rawroot'"' == "" {
    di as error "Set REFUGEE_RAW_DATA to the raw-data root folder"
    exit 601
}

* ---- parameters: uncomment ONE survey block ------------------------------
local processid 39                       // FDPRaw-data

local surveyid  "TCD_2022_EHCVM_V01_M"
local files     `""`rawroot'/Chad/household_TCD_2022.dta" "`rawroot'/Chad/individual_TCD_2022.dta""'

*local surveyid  "COL_2023_GEIH_V01_M"
*local files     `""`rawroot'/Colombia/GEIH/household_data_2023.dta" "`rawroot'/Colombia/GEIH/individual_data_2023.dta""'

*local surveyid  "UGA_2018_RHS_V01_M"
*local files     `""`rawroot'/Uganda/UGA_hh.dta" "`rawroot'/Uganda/UGA_ind.dta""'

* Optional supporting documents (questionnaires, reports) for the Doc/Questionnaires folder
local docs      ""

* ---- upload: first file opens a NEW transaction ---------------------------
local first 1
foreach f of local files {
    if `first' {
        primus upload, processid(`processid') surveyid(`surveyid') ///
            type(raw) folderpath(Data/Stata) infile("`f'") new
        local tranxid = r(prmTransId)
        di as result "Opened transaction `tranxid'"
        local first 0
    }
    else {
        primus upload, processid(`processid') surveyid(`surveyid') ///
            type(raw) folderpath(Data/Stata) infile("`f'") tranxid(`tranxid')
    }
}

* questionnaires and documentation travel with the microdata
foreach f of local docs {
    primus upload, processid(`processid') surveyid(`surveyid') ///
        type(raw) folderpath(Doc/Questionnaires) infile("`f'") tranxid(`tranxid')
}

* ---- confirm the draft so it becomes visible to approvers -----------------
primus action, tranxid(`tranxid') processid(`processid') ///
    decision(confirm) comments(raw data ready for review)

di as result "Raw upload confirmed: `surveyid' (transaction `tranxid')"
