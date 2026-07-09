# =====================================================================
# 04_review_harmonized.R
# 50by35 pipeline — Step 3 (reviewer): approve or reject a
# harmonized-data transaction via PRIMUS (R client). Requires approver
# status and a stored token (primus_set_token).
#
# Review the indicator XML (self-reliance share at $3.00/day 2021 PPP)
# before approving. Approved files are published to Datalibweb for
# 50by35 monitoring. A decision is final and cannot be changed.
# =====================================================================

library(primus)

# ---- parameters --------------------------------------------------------------
process_name   <- "FDP-harmonized-data"
transaction_id <- "0040-000587256-FDP-COL-2FAD1"                    # e.g. "040-000327173-..."

# ---- what is waiting for review? ----------------------------------------------
pending <- primus_query_transactions(process_name, status = "pending")
print(pending)

if (transaction_id == "")
  stop("Set transaction_id to a transaction from the list above, then rerun")

# ---- inspect before deciding ----------------------------------------------------
primus_transaction_details(transaction_id)

primus_transaction_files(transaction_id)

# ---- download files ----------------------------------------------------------

# get the indicator XML (check the reported self-reliance values)
primus_get_xml(transaction_id,
               out = file.path(tempdir(), paste0(transaction_id, ".xml")))
  
# ---- decision: run ONE ---------------------------------------------------------
primus_approve(transaction_id,
               comments = "test harmonized data approved for publication")

# primus_reject(transaction_id, comments = "<explain what must be fixed>")
