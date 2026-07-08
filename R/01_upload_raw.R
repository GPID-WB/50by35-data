# =====================================================================
# 01_upload_raw.R
# 50by35 pipeline — Step 1: upload raw microdata via PRIMUS (R client)
#
# Requires: the primus R package (remotes::install_github("worldbank/primus-r"))
# and a stored Datalibweb token (valid 30 days, shared with the dlw package):
#     primus::primus_set_token("<your Datalibweb token>")
#
# The raw process name below (FDPRaw-data) is illustrative — verify with
# primus_list_processes().
# =====================================================================

library(primus)

rawroot <- Sys.getenv("REFUGEE_RAW_DATA")
if (rawroot == "") stop("Set REFUGEE_RAW_DATA to the raw-data root folder")

# ---- parameters: pick ONE survey block -------------------------------------
process_name <- "FDPRaw-data"

survey_id <- "TCD_2022_EHCVM_V01_M"
files <- file.path(rawroot, "Chad",
                   c("household_TCD_2022.dta", "individual_TCD_2022.dta"))

# survey_id <- "COL_2023_GEIH_V01_M"
# files <- file.path(rawroot, "Colombia/GEIH",
#                    c("household_data_2023.dta", "individual_data_2023.dta"))

# survey_id <- "UGA_2018_RHS_V01_M"
# files <- file.path(rawroot, "Uganda", c("UGA_hh.dta", "UGA_ind.dta"))

# Optional supporting documents (questionnaires, reports) for the Doc/Questionnaires folder
docs <- character(0)

# ---- upload: first file opens a NEW transaction ------------------------------
up <- primus_upload(
  process_name = process_name,
  survey_id    = survey_id,
  type         = "raw",
  infile       = files[1],
  folder_name  = "Data/Stata"
)
message("Opened transaction ", up$transaction_id)

for (f in files[-1]) {
  primus_upload(
    process_name   = process_name,
    survey_id      = survey_id,
    type           = "raw",
    infile         = f,
    folder_name    = "Data/Stata",
    transaction_id = up$transaction_id
  )
}

# questionnaires and documentation travel with the microdata
for (f in docs) {
  primus_upload(
    process_name   = process_name,
    survey_id      = survey_id,
    type           = "raw",
    infile         = f,
    folder_name    = "Doc/Questionnaires",
    transaction_id = up$transaction_id
  )
}

# ---- confirm the draft so it becomes visible to approvers -------------------
primus_confirm(up$transaction_id, comments = "raw data ready for review")
message("Raw upload confirmed: ", survey_id, " (transaction ", up$transaction_id, ")")
