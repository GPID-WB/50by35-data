/* =====================================================================
04_review_harmonized.do
50by35 pipeline — Step 3 (reviewer): approve or reject a harmonized-data
transaction via PRIMUS (Stata client). Requires approver status and a
registered token (primus register, token(...)).

Review the indicator XML (self-reliance share at $3.00/day 2021 PPP)
before approving. Approved files are published to Datalibweb for 50by35
monitoring. An approve/reject decision is final and cannot be changed.
===================================================================== */

version 18
clear
set more off

* ---- parameters -----------------------------------------------------------
local processid 40                                    // FDP-harmonized-data
local tranxid   ""                                    // e.g. 040-000327173-...

* ---- what is waiting for review? ------------------------------------------
primus query, process(`processid') overallstatus(PENDING)

if "`tranxid'" == "" {
    di as error "Set tranxid to a transaction from the list above, then rerun"
    exit 198
}

* files attached to the transaction, and the indicator values
primus download, processid(`processid') tranxid(`tranxid') filelist
primus download, processid(`processid') tranxid(`tranxid') indicator

* the indicator XML itself (inspect the SelfReliantShare value)
primus download, xml processid(`processid') tranxid(`tranxid') ///
    outfile("indicator_`tranxid'.xml")

* ---- decision: uncomment ONE ----------------------------------------------
primus action, tranxid(`tranxid') processid(`processid') ///
    decision(approve) comments(harmonized data approved for publication)

*primus action, tranxid(`tranxid') processid(`processid') ///
*    decision(reject) comments(<explain what must be fixed>)
