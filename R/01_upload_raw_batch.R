# =====================================================================
# 01_upload_raw_batch.R
# 50by35 pipeline — Step 1 (batch): upload raw microdata for multiple
# surveys via PRIMUS (R client).
#
# Reads batch/01_raw_uploads.csv with columns:
#   survey_id  — e.g. "COL_2023_GEIH_V01_M"
#   files      — semicolon-separated paths relative to $REFUGEE_RAW_DATA
#   docs       — (optional) semicolon-separated doc paths relative to $REFUGEE_RAW_DATA
#
# Failures are logged and skipped; a summary is printed at the end.
# =====================================================================

library(primus)

manifest <- read.csv("batch/01_raw_uploads.csv", stringsAsFactors = FALSE)

rawroot <- Sys.getenv("REFUGEE_RAW_DATA")
if (rawroot == "") stop("Set REFUGEE_RAW_DATA to the raw-data root folder")

process_name <- "FDPRaw-data"

# ---- batch loop --------------------------------------------------------------
results <- data.frame(
  survey_id      = character(),
  status         = character(),
  transaction_id = character(),
  message        = character(),
  stringsAsFactors = FALSE
)

for (i in seq_len(nrow(manifest))) {
  row <- manifest[i, ]
  sid <- trimws(row$survey_id)
  message("\n=== [", i, "/", nrow(manifest), "] ", sid, " ===")

  tryCatch({
    files <- file.path(rawroot, trimws(strsplit(row$files, ";")[[1]]))
    docs  <- if (!is.na(row$docs) && nzchar(trimws(row$docs)))
               file.path(rawroot, trimws(strsplit(row$docs, ";")[[1]]))
             else character(0)

    # first file opens a new transaction
    up <- primus_upload(
      process_name = process_name,
      survey_id    = sid,
      type         = "raw",
      infile       = files[1],
      folder_name  = "Data/Stata"
    )
    tid <- up$transaction_id
    message("  Opened transaction ", tid)

    for (f in files[-1]) {
      primus_upload(
        process_name   = process_name,
        survey_id      = sid,
        type           = "raw",
        infile         = f,
        folder_name    = "Data/Stata",
        transaction_id = tid
      )
    }

    for (f in docs) {
      primus_upload(
        process_name   = process_name,
        survey_id      = sid,
        type           = "raw",
        infile         = f,
        folder_name    = "Doc/Questionnaires",
        transaction_id = tid
      )
    }

    primus_confirm(tid, comments = "raw data ready for review")
    message("  Confirmed: ", sid)

    results <- rbind(results, data.frame(
      survey_id = sid, status = "ok", transaction_id = tid, message = "",
      stringsAsFactors = FALSE
    ))

  }, error = function(e) {
    message("  FAILED: ", conditionMessage(e))
    results <<- rbind(results, data.frame(
      survey_id = sid, status = "FAILED", transaction_id = NA,
      message = conditionMessage(e), stringsAsFactors = FALSE
    ))
  })
}

# ---- summary -----------------------------------------------------------------
message("\n=== Batch summary (01_upload_raw) ===")
for (j in seq_len(nrow(results))) {
  r <- results[j, ]
  if (r$status == "ok") {
    message("  OK:     ", r$survey_id, " (transaction ", r$transaction_id, ")")
  } else {
    message("  FAILED: ", r$survey_id, " — ", r$message)
  }
}

n_fail <- sum(results$status != "ok")
if (n_fail > 0) warning(n_fail, " of ", nrow(results), " uploads failed")
