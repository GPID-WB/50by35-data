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

# ---- inspect the files before deciding ----------------------------------------
primus_transaction_details(transaction_id)
files <- primus_download_data(transaction_id,
                              dest_dir = file.path(tempdir(), transaction_id))
print(files)

# ---- decision: run ONE ---------------------------------------------------------
primus_approve(transaction_id, comments = "raw data approved for harmonization")

# primus_reject(transaction_id, comments = "<explain what must be fixed>")
