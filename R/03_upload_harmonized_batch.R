# =====================================================================
# 03_upload_harmonized_batch.R
# 50by35 pipeline — Step 3 (batch): validate, build indicator XML, and
# upload harmonized files for multiple surveys via PRIMUS (R client).
#
# Workflow:
#   1. Scans data/processed/ for *_WELF.dta files and matches each to
#      a Stata/*_WELF.do harmonization script.
#   2. Writes batch/03_harmonized_uploads.csv with the discovered
#      surveys. Edit the CSV to remove rows, add cpi/ppp overrides,
#      etc. before the script proceeds.
#   3. Reads the CSV back and processes each row.
#
# Failures are logged and skipped; a summary is printed at the end.
# =====================================================================

library(primus)
library(pipr)
library(haven)

source("R/validate_50by35.R")

outdir        <- Sys.getenv("FIFTYBY35_PROCESSED", "data/processed")
process_name  <- "FDP-harmonized-data"
zline         <- 3.00  # placeholder poverty line, $/day 2021 PPP
manifest_file <- "batch/03_harmonized_uploads.csv"

# ---- auto-generate manifest from processed .dta files ------------------------
dta_files <- list.files(outdir, pattern = "_WELF\\.dta$", full.names = FALSE)

if (length(dta_files) == 0) {
  stop("No *_WELF.dta files found in ", outdir)
}

# derive survey_id by stripping _WELF.dta suffix
survey_ids  <- sub("_WELF\\.dta$", "", dta_files)

# match to harmonization scripts
harm_scripts <- file.path("Stata", paste0(survey_ids, "_WELF.do"))
script_exists <- file.exists(harm_scripts)

manifest <- data.frame(
  survey_id    = survey_ids,
  harm_script  = harm_scripts,
  cpi_override = "",
  ppp_override = "",
  stringsAsFactors = FALSE
)

write.csv(manifest, manifest_file, row.names = FALSE)

message("Wrote ", manifest_file, " with ", nrow(manifest), " survey(s) found in ", outdir, ".")
if (any(!script_exists)) {
  message("  WARNING: harmonization script not found for:")
  for (s in survey_ids[!script_exists]) message("    ", s)
}
message("  Edit the CSV now to remove surveys you don't want to upload,")
message("  add cpi/ppp overrides, etc. Then press ENTER to continue (or Ctrl-C to abort).")
readline()

# ---- read manifest back (user may have edited it) ----------------------------
manifest <- read.csv(manifest_file, stringsAsFactors = FALSE)

# ---- fetch PIP tables once for all surveys -----------------------------------
cpi_pip <- get_aux("cpi", ppp_version = 2021)
ppp_pip <- get_aux("ppp", ppp_version = 2021)

# ---- helpers -----------------------------------------------------------------
kv <- function(...) {
  vals <- c(...)
  paste(names(vals), vals, sep = ";")
}
cdata_block <- function(lines) c("<![CDATA[", "key;value", lines, "]]>")

# CPI fallback: interpolate or use nearest year when exact match unavailable
get_cpi_fallback <- function(cpi_table, ccode, yr) {
  cc <- cpi_table[cpi_table$country_code == ccode &
                    cpi_table$data_level == "national" &
                    !is.na(cpi_table$value), ]
  if (nrow(cc) == 0) stop("PIP has no CPI data at all for ", ccode)

  cc$yr_num <- as.integer(as.character(cc$year))
  below <- cc[cc$yr_num <= yr, ]
  above <- cc[cc$yr_num >= yr, ]

  if (nrow(below) > 0 && nrow(above) > 0) {
    lo <- below[which.max(below$yr_num), ]
    hi <- above[which.min(above$yr_num), ]
    if (lo$yr_num == hi$yr_num) {
      # exact match after all
      return(list(value = lo$value, method = "EmbeddedCPI"))
    }
    # linear interpolation
    frac <- (yr - lo$yr_num) / (hi$yr_num - lo$yr_num)
    cpi_val <- lo$value + frac * (hi$value - lo$value)
    method <- sprintf("Interpolated(CPI_%s=%.6f,CPI_%s=%.6f)",
                      lo$yr_num, lo$value, hi$yr_num, hi$value)
    return(list(value = cpi_val, method = method))
  }

  # edge case: only one side available — use nearest
  nearest <- cc[which.min(abs(cc$yr_num - yr)), ]
  method <- sprintf("NearestYear(CPI_%s=%.6f)", nearest$yr_num, nearest$value)
  return(list(value = nearest$value, method = method))
}

# ---- batch loop --------------------------------------------------------------
results <- data.frame(
  survey_id      = character(),
  status         = character(),
  transaction_id = character(),
  sr_share       = numeric(),
  headcount      = numeric(),
  message        = character(),
  stringsAsFactors = FALSE
)

for (i in seq_len(nrow(manifest))) {
  row <- manifest[i, ]
  sid         <- trimws(row$survey_id)
  harm_script <- trimws(row$harm_script)
  cpi_ov      <- if (!is.na(row$cpi_override) && nzchar(trimws(as.character(row$cpi_override))))
                   as.numeric(row$cpi_override) else NA
  ppp_ov      <- if (!is.na(row$ppp_override) && nzchar(trimws(as.character(row$ppp_override))))
                   as.numeric(row$ppp_override) else NA

  message("\n=== [", i, "/", nrow(manifest), "] ", sid, " ===")

  tryCatch({
    dta_file <- file.path(outdir, paste0(sid, "_WELF.dta"))

    # ---- validation -----------------------------------------------------------
    df <- read_dta(dta_file)
    validate_50by35(df)

    ccode <- df$code[1]
    yr    <- df$year[1]

    # ---- CPI / PPP ------------------------------------------------------------
    cpi_method <- "EmbeddedCPI"  # default; updated if fallback used

    if (is.na(cpi_ov)) {
      cpi <- cpi_pip[cpi_pip$country_code == ccode &
                       as.integer(as.character(cpi_pip$year)) == yr &
                       cpi_pip$data_level == "national", ]
      if (nrow(cpi) == 1 && !is.na(cpi$value)) {
        cpi_value <- cpi$value
      } else {
        # fallback: interpolate or nearest year
        fb <- get_cpi_fallback(cpi_pip, ccode, yr)
        cpi_value  <- fb$value
        cpi_method <- fb$method
        message("  CPI fallback: ", cpi_method)
      }
    } else {
      cpi_value <- cpi_ov
      cpi_method <- "ManualOverride"
    }

    if (is.na(ppp_ov)) {
      ppp <- ppp_pip[ppp_pip$country_code == ccode &
                       ppp_pip$data_level == "national", ]
      if (nrow(ppp) < 1 || is.na(ppp$value[1]))
        stop("PIP has no 2021 PPP for ", ccode, " — set ppp_override in the manifest")
      icp_value <- ppp$value[1]
    } else icp_value <- ppp_ov

    message("  CPI(", ccode, ",", yr, ") = ", cpi_value,
            "   PPP2021(", ccode, ") = ", icp_value)

    # ---- indicators -----------------------------------------------------------
    sr_share  <- weighted.mean(df$welfare_self / 365 / cpi_value / icp_value >= zline,
                               df$weight)
    headcount <- weighted.mean(df$welfare / 365 / cpi_value / icp_value < zline,
                               df$weight)
    mean_lcu      <- weighted.mean(df$welfare, df$weight)
    mean_lcu_self <- weighted.mean(df$welfare_self, df$weight)
    message(sprintf("  Self-reliance share (z=$%.2f/day 2021 PPP): %.4f", zline, sr_share))

    # ---- write indicator XML ---------------------------------------------------
    request_cdata <- cdata_block(kv(
      APP_ID       = "R",
      DATETIME     = format(Sys.time(), "%d %b %Y %H:%M:%S"),
      COUNTRY_CODE = ccode,
      FILENAME     = basename(dta_file),
      DATA_YEAR    = yr,
      REF_YEAR     = yr,
      PPP_YEAR     = "2021"
    ))

    datasummary_cdata <- cdata_block(kv(
      nRecs                 = nrow(df),
      Mean_LCU_welfare      = sprintf("%.2f", mean_lcu),
      Mean_LCU_welfare_self = sprintf("%.2f", mean_lcu_self)
    ))

    calc_headcount_cdata <- cdata_block(kv(
      Indicator   = "PovertyHeadcount",
      Variable    = "welfare",
      PovertyLine = sprintf("%.2f", zline),
      Method      = cpi_method,
      CPIValue    = sprintf("%.6f", cpi_value),
      PPPValue    = sprintf("%.6f", icp_value),
      Value       = sprintf("%.6f", headcount)
    ))

    calc_selfreliance_cdata <- cdata_block(kv(
      Indicator   = "SelfRelianceShare",
      Variable    = "welfare_self",
      PovertyLine = sprintf("%.2f", zline),
      Method      = cpi_method,
      CPIValue    = sprintf("%.6f", cpi_value),
      PPPValue    = sprintf("%.6f", icp_value),
      Value       = sprintf("%.6f", sr_share)
    ))

    log_detail_cdata <- c(
      "<![CDATA[",
      sprintf("50by35 self-reliance indicator for %s.", sid),
      sprintf(paste0("welfare_self / 365 / CPI(%s,%s)=%.6f / PPP2021(%s)=%.6f >= z=%.2f",
                     " (placeholder, pending confirmation from the 50by35 methodology team)."),
              ccode, yr, cpi_value, ccode, icp_value, zline),
      sprintf("PovertyHeadcount (welfare, same z): %.6f", headcount),
      sprintf("SelfRelianceShare (welfare_self): %.6f", sr_share),
      "]]>"
    )

    xml_file <- file.path(outdir, paste0(sid, ".xml"))
    writeLines(c(
      "<PRIMUS_ANALYSIS>",
      "  <Request>",
      "    <RequestKey><![CDATA[]]></RequestKey>",
      "    <welfare>welfare_self</welfare>",
      "    <weight>weight</weight>",
      "    <By></By>",
      "    <N_By_Group>1</N_By_Group>",
      "    <nParamSets>2</nParamSets>",
      paste0("    ", request_cdata),
      "  </Request>",
      "  <Result>",
      '    <Welfare var="welfare_self" weight="weight">',
      '      <ByGroup byCondition="none">',
      "        <DATASUMMARY>",
      paste0("          ", datasummary_cdata),
      "        </DATASUMMARY>",
      "        <CALCULATION>",
      paste0("          ", calc_headcount_cdata),
      "        </CALCULATION>",
      "        <CALCULATION>",
      paste0("          ", calc_selfreliance_cdata),
      "        </CALCULATION>",
      "      </ByGroup>",
      "    </Welfare>",
      "  </Result>",
      "  <LOG_DETAIL>",
      paste0("    ", log_detail_cdata),
      "  </LOG_DETAIL>",
      "</PRIMUS_ANALYSIS>"
    ), xml_file)
    message("  Wrote ", xml_file)

    # ---- upload ---------------------------------------------------------------
    up <- primus_upload(
      process_name = process_name,
      survey_id    = sid,
      type         = "harmonized",
      infile       = xml_file,
      xml          = xml_file
    )
    tid <- up$transaction_id
    message("  Opened transaction ", tid)

    primus_upload(
      process_name   = process_name,
      survey_id      = sid,
      type           = "harmonized",
      infile         = dta_file,
      folder_name    = "Data/Harmonized",
      transaction_id = tid
    )

    primus_upload(
      process_name   = process_name,
      survey_id      = sid,
      type           = "harmonized",
      infile         = harm_script,
      folder_name    = "Programs",
      transaction_id = tid
    )

    primus_confirm(tid, comments = "harmonized data ready for review")
    message("  Confirmed: ", sid)

    results <- rbind(results, data.frame(
      survey_id = sid, status = "ok", transaction_id = tid,
      sr_share = sr_share, headcount = headcount, message = "",
      stringsAsFactors = FALSE
    ))

  }, error = function(e) {
    message("  FAILED: ", conditionMessage(e))
    results <<- rbind(results, data.frame(
      survey_id = sid, status = "FAILED", transaction_id = NA,
      sr_share = NA, headcount = NA, message = conditionMessage(e),
      stringsAsFactors = FALSE
    ))
  })
}

# ---- summary -----------------------------------------------------------------
message("\n=== Batch summary (03_upload_harmonized) ===")
for (j in seq_len(nrow(results))) {
  r <- results[j, ]
  if (r$status == "ok") {
    message(sprintf("  OK:     %s (transaction %s) SR=%.4f HC=%.4f",
                    r$survey_id, r$transaction_id, r$sr_share, r$headcount))
  } else {
    message("  FAILED: ", r$survey_id, " — ", r$message)
  }
}

n_fail <- sum(results$status != "ok")
if (n_fail > 0) warning(n_fail, " of ", nrow(results), " uploads failed")
