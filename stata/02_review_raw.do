/* =====================================================================
02_review_raw.do
50by35 pipeline — Step 1 (reviewer): approve or reject a raw-data
transaction via PRIMUS (Stata client). Requires approver status and a
registered token (primus register, token(...)).

Note: the Stata client lists transactions and their files but does not
download the data files themselves — inspect the files on the PRIMUS
web interface or with the R client (primus_download_data) before
approving. An approve/reject decision is final and cannot be changed.
===================================================================== */

version 18
clear
set more off

* ---- parameters -----------------------------------------------------------
local processid 39                                    // FDPRaw-data
local tranxid   ""                                    // e.g. 039-000327173-...

* ---- what is waiting for review? ------------------------------------------
primus query, process(`processid') overallstatus(PENDING)

if "`tranxid'" == "" {
    di as error "Set tranxid to a transaction from the list above, then rerun"
    exit 198
}

* files attached to the transaction
primus download, processid(`processid') tranxid(`tranxid') filelist

* ---- decision: uncomment ONE ----------------------------------------------
primus action, tranxid(`tranxid') processid(`processid') ///
    decision(approve) comments(raw data approved for harmonization)

*primus action, tranxid(`tranxid') processid(`processid') ///
*    decision(reject) comments(<explain what must be fixed>)
