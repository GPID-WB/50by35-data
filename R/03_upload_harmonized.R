# =====================================================================
# 03_upload_harmonized.R
# 50by35 pipeline — Step 3: validate, build the indicator XML, and
# upload a harmonized file via PRIMUS (R client).
#
# The transaction starts from an indicator XML that records the 50by35
# self-reliance indicator for the reviewer to approve; the data and
# harmonization scripts are then attached to the same transaction.
#
# The XML is written directly by this script. PRIMUS accepts a
# team-defined XML as long as it follows the main heading format
# (<PRIMUS_ANALYSIS><Request>...<Result>); the same structure is written
# by Stata/03_upload_harmonized.do. For the full standard GMD indicator
# document (Gini, deciles, FGT at the fixed $3.00/$4.20/$8.30 lines),
# primus::create_xml() is an alternative, but it has no self-reliance
# field and its poverty-line set cannot be customized.
#
# CPI and 2021 PPP conversion factors come from the World Bank PIP API
# via the pipr package (install.packages("pipr")). z = $3.00/day 2021 PPP.
#
# Requires: primus R package + stored token; pipr; haven.
# Run from the repository root. The process name (FDP-harmonized-data)
# is illustrative — verify with primus_list_processes().
# =====================================================================

library(primus)
library(pipr)
library(haven)

source("R/validate_50by35.R")

outdir <- Sys.getenv("FIFTYBY35_PROCESSED", "data/processed")

# ---- parameters: pick ONE survey block --------------------------------------
process_name <- "FDP-harmonized-data"
zline        <- 3.00                    # poverty line, $/day 2021 PPP

survey_id   <- "TCD_2022_EHCVM_V01_M_V01_A_FDP"
harm_script <- "Stata/TCD_2022_EHCVM_V01_M_V01_A_FDP_WELF.do"

# survey_id   <- "COL_2023_GEIH_V01_M_V01_A_FDP"
# harm_script <- "Stata/COL_2023_GEIH_V01_M_V01_A_FDP_WELF.do"

# survey_id   <- "UGA_2018_RHS_V01_M_V01_A_FDP"
# harm_script <- "Stata/UGA_2018_RHS_V01_M_V01_A_FDP_WELF.do"

dta_file <- file.path(outdir, paste0(survey_id, "_WELF.dta"))

# PIP's CPI is only populated for country-years with a PIP survey. For
# surveys outside PIP (e.g. UGA_2018_RHS), set cpi_override to the ratio
# CPI(survey year)/CPI(2021) from the national CPI series (e.g. WDI
# FP.CPI.TOTL); the Uganda 2018 value from the report package is
# 171.14172/185.89218 = 0.92066.
cpi_override <- NA
ppp_override <- NA

# ---- validation: any schema violation stops before upload --------------------
df <- read_dta(dta_file)
validate_50by35(df)

ccode <- df$code[1]
year  <- df$year[1]

# ---- CPI / PPP conversion factors from PIP, pinned to the 2021 framework ------
# CPI: normalized to 1 in 2021, aligned to the survey fieldwork period.
# PPP: ICP 2021 conversion factor (LCU per 2021 international $).
if (is.na(cpi_override)) {
  cpi <- get_aux("cpi", ppp_version = 2021)
  cpi <- cpi[cpi$country_code == ccode &
               as.integer(as.character(cpi$year)) == year &
               cpi$data_level == "national", ]
  if (nrow(cpi) != 1 || is.na(cpi$value))
    stop("PIP has no CPI for ", ccode, " ", year,
         " (survey not in PIP?) — set cpi_override to CPI(", year,
         ")/CPI(2021) from the national CPI series (e.g. WDI FP.CPI.TOTL)")
  cpi_value <- cpi$value
} else cpi_value <- cpi_override

if (is.na(ppp_override)) {
  ppp <- get_aux("ppp", ppp_version = 2021)
  ppp <- ppp[ppp$country_code == ccode & ppp$data_level == "national", ]
  if (nrow(ppp) < 1 || is.na(ppp$value[1]))
    stop("PIP has no 2021 PPP for ", ccode, " — set ppp_override")
  icp_value <- ppp$value[1]
} else icp_value <- ppp_override

message("CPI(", ccode, ",", year, ") = ", cpi_value,
        "   PPP2021(", ccode, ") = ", icp_value)

# ---- 50by35 self-reliance indicator --------------------------------------------
sr_share <- weighted.mean(df$welfare_self / 365 / cpi_value / icp_value >= zline,
                          df$weight)
headcount <- weighted.mean(df$welfare / 365 / cpi_value / icp_value < zline,
                           df$weight)
mean_lcu <- weighted.mean(df$welfare, df$weight)
message(sprintf("Self-reliance share (z=$%.2f/day 2021 PPP): %.4f", zline, sr_share))

# ---- write the indicator XML (same structure as the Stata client) ---------------
xml_file <- file.path(outdir, paste0(survey_id, ".xml"))
writeLines(c(
  "<PRIMUS_ANALYSIS>",
  "  <Request>",
  "    <welfare>welfare,welfare_self</welfare>",
  "    <weight>weight</weight>",
  "    <![CDATA[APP_ID=R",
  format(Sys.time(), "DATETIME=%d %b %Y %H:%M:%S"),
  paste0("COUNTRY_CODE=", ccode),
  paste0("FILENAME=", basename(dta_file)),
  paste0("DATA_YEAR=", year),
  paste0("REF_YEAR=", year),
  "PPP_YEAR=2021]]>",
  "  </Request>",
  "  <Result>",
  '    <ByGroup byCondition="none">',
  sprintf('      <DATASUMMARY nRecs="%d" Mean_LCU="%.2f" />', nrow(df), mean_lcu),
  sprintf(paste0('      <CALCULATION povertyLine="%.2f" method="EmbeddedCPI"',
                 ' CPIValue="%s" PPPValue="%s" Headcount="%.6f"',
                 ' SelfReliantShare="%.6f" />'),
          zline, cpi_value, icp_value, headcount, sr_share),
  "    </ByGroup>",
  "  </Result>",
  "</PRIMUS_ANALYSIS>"
), xml_file)
message("Wrote ", xml_file)

# ---- upload: XML opens the transaction, then attach data + programs -----------
up <- primus_upload(
  process_name = process_name,
  survey_id    = survey_id,
  type         = "harmonized",
  infile       = xml_file,
  xml          = xml_file,
  folder_name  = "Data/Harmonized"
)
message("Opened transaction ", up$transaction_id)

primus_upload(
  process_name   = process_name,
  survey_id      = survey_id,
  type           = "harmonized",
  infile         = dta_file,
  folder_name    = "Data/Harmonized",
  transaction_id = up$transaction_id
)

# harmonization code makes the upload reproducible from source
primus_upload(
  process_name   = process_name,
  survey_id      = survey_id,
  type           = "harmonized",
  infile         = harm_script,
  folder_name    = "Programs",
  transaction_id = up$transaction_id
)

# ---- confirm the draft so it becomes visible to approvers ---------------------
primus_confirm(up$transaction_id, comments = "harmonized data ready for review")
message("Harmonized upload confirmed: ", survey_id,
        " (transaction ", up$transaction_id, ")")
