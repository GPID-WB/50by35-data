# =====================================================================
# 04_review_harmonized_batch.R
# 50by35 pipeline — Step 3 reviewer (batch): approve or reject multiple
# harmonized-data transactions via PRIMUS (R client).
#
# Workflow:
#   1. Queries PRIMUS for all pending harmonized-data transactions.
#   2. Writes batch/04_harmonized_reviews.csv with decision defaulting
#      to "approve". Edit the CSV to change decisions or comments before
#      the script proceeds.
#   3. Reads the CSV back and processes each row.
#
# Review the indicator XML (self-reliance share at $3.00/day 2021 PPP)
# before approving. Approved files are published to Datalibweb for
# 50by35 monitoring. A decision is final and cannot be changed.
# Failures are logged and skipped; a summary is printed at the end.
# =====================================================================

library(primus)

process_name  <- "FDP-harmonized-data"
manifest_file <- "batch/04_harmonized_reviews.csv"

# ---- auto-generate manifest from pending transactions ------------------------
message("=== Querying pending harmonized-data transactions ===")
pending <- primus_query_transactions(process_name, status = "pending")

if (nrow(pending) == 0) {
  message("No pending harmonized-data transactions — nothing to review.")
  quit(save = "no")
}

manifest <- data.frame(
  transaction_id = pending$TransactionId,
  survey_id      = pending$SurveyId,
  decision       = "approve",
  comments       = "test harmonized data upload",
  stringsAsFactors = FALSE
)

write.csv(manifest, manifest_file, row.names = FALSE)
message("Wrote ", manifest_file, " with ", nrow(manifest), " pending transaction(s).")
message("  Default decision: approve. Edit the CSV now if you want to change")
message("  any decisions, then press ENTER to continue (or Ctrl-C to abort).")
readline()

# ---- read manifest back (user may have edited it) ----------------------------
manifest <- read.csv(manifest_file, stringsAsFactors = FALSE)

# ---- batch loop --------------------------------------------------------------
results <- data.frame(
  transaction_id = character(),
  decision       = character(),
  status         = character(),
  message        = character(),
  stringsAsFactors = FALSE
)

for (i in seq_len(nrow(manifest))) {
  row <- manifest[i, ]
  tid      <- trimws(row$transaction_id)
  decision <- tolower(trimws(row$decision))
  comments <- if (!is.na(row$comments) && nzchar(trimws(row$comments)))
                trimws(row$comments)
              else paste("harmonized data", decision, "d")

  message("\n=== [", i, "/", nrow(manifest), "] ", tid, " (", decision, ") ===")

  if (!decision %in% c("approve", "reject")) {
    message("  SKIPPED: invalid decision '", decision, "' — must be 'approve' or 'reject'")
    results <- rbind(results, data.frame(
      transaction_id = tid, decision = decision, status = "SKIPPED",
      message = "invalid decision", stringsAsFactors = FALSE
    ))
    next
  }

  tryCatch({
    message("  Files:")
    print(primus_transaction_files(tid))

    # download the indicator XML for logging
    xml_out <- file.path(tempdir(), paste0(tid, ".xml"))
    primus_get_xml(tid, out = xml_out)
    message("  Indicator XML saved to ", xml_out)

    if (decision == "approve") {
      primus_approve(tid, comments = comments)
    } else {
      primus_reject(tid, comments = comments)
    }

    message("  ", toupper(decision), "D: ", tid)
    results <- rbind(results, data.frame(
      transaction_id = tid, decision = decision, status = "ok", message = "",
      stringsAsFactors = FALSE
    ))

  }, error = function(e) {
    message("  FAILED: ", conditionMessage(e))
    results <<- rbind(results, data.frame(
      transaction_id = tid, decision = decision, status = "FAILED",
      message = conditionMessage(e), stringsAsFactors = FALSE
    ))
  })
}

# ---- summary -----------------------------------------------------------------
message("\n=== Batch summary (04_review_harmonized) ===")
for (j in seq_len(nrow(results))) {
  r <- results[j, ]
  if (r$status == "ok") {
    message("  OK:     ", r$transaction_id, " (", r$decision, ")")
  } else {
    message("  ", r$status, ": ", r$transaction_id, " — ", r$message)
  }
}

n_fail <- sum(results$status != "ok")
if (n_fail > 0) warning(n_fail, " of ", nrow(results), " reviews failed or skipped")
