# =====================================================================
# 02_review_raw.R
# 50by35 pipeline — Step 1 (reviewer): approve or reject a raw-data
# transaction via PRIMUS (R client). Requires approver status and a
# stored token (primus_set_token).
#
# An approve/reject decision is final and cannot be changed.
# =====================================================================

library(primus)

# ---- parameters -------------------------------------------------------------
process_name   <- "FDPRaw-data"
transaction_id <- ""                    # e.g. "039-000327173-..."

# ---- what is waiting for review? ---------------------------------------------
pending <- primus_query_transactions(process_name, status = "pending")
print(pending)

if (transaction_id == "")
  stop("Set transaction_id to a transaction from the list above, then rerun")

transaction_id <- "0039-000587256-FDPRAW-COL-23596"

# ---- inspect the files before deciding ----------------------------------------
primus_transaction_files(transaction_id)

# ---- download files ----------------------------------------------------------


# ---- decision: run ONE ---------------------------------------------------------
primus_approve(transaction_id, comments = "test raw data approved for harmonization")

# primus_reject(transaction_id, comments = "<explain what must be fixed>")
