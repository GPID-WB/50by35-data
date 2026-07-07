# =====================================================================
# validate_50by35.R
# Validate a harmonized data frame against the 50by35 schema
# (see chapters/05-schema.qmd). Stops with an error on any violation,
# preventing upload of a non-conforming file.
#
# Usage:  source("R/validate_50by35.R")
#         df <- haven::read_dta("<harmonized file>.dta")
#         validate_50by35(df)
# =====================================================================

validate_50by35 <- function(df) {
  fail <- function(...) stop("SCHEMA ERROR: ", ..., call. = FALSE)

  mandatory <- c("countrycode", "year", "hhid", "pid", "welfare",
                 "welfare_type", "welfare_self", "weight", "camp", "urban")
  missing_vars <- setdiff(mandatory, names(df))
  if (length(missing_vars))
    fail("mandatory variable(s) missing: ", paste(missing_vars, collapse = ", "))

  # identifiers: strings, 3-letter country code, unique hhid x pid
  for (v in c("countrycode", "hhid", "pid"))
    if (!is.character(df[[v]])) fail(v, " must be a string")
  if (any(nchar(df$countrycode) != 3)) fail("countrycode must be a 3-letter code")
  if (anyDuplicated(df[c("hhid", "pid")])) fail("hhid + pid do not uniquely identify rows")

  # missing values (camp/urban may be missing)
  for (v in c("year", "welfare", "welfare_type", "welfare_self", "weight"))
    if (anyNA(df[[v]])) fail("missing values in mandatory variable ", v)
  if (any(df$hhid == "" | df$pid == "")) fail("empty hhid or pid")

  # value ranges
  if (any(df$year < 1990 | df$year > 2035)) fail("year outside 1990-2035")
  if (any(df$welfare <= 0)) fail("welfare must be strictly positive")
  if (any(df$weight <= 0)) fail("weight must be strictly positive")
  if (any(df$welfare_self < 0)) fail("welfare_self must be non-negative")
  if (any(df$welfare_self > df$welfare)) fail("welfare_self greater than welfare")
  if (!all(df$welfare_type %in% 1:3)) fail("welfare_type outside 1-3")
  for (v in c("camp", "urban"))
    if (!all(df[[v]] %in% c(0, 1, NA))) fail(v, " must be 0/1 or missing")

  # optional variables, when present
  if ("hhsize" %in% names(df)) {
    if (any(df$hhsize < 1, na.rm = TRUE)) fail("hhsize below 1")
    # mismatch with the person-record count is a warning: rosters can be
    # incomplete, and refugee-only samples keep a subset of members
    npid <- ave(seq_len(nrow(df)), df$hhid, FUN = length)
    n_bad <- sum(df$hhsize != npid, na.rm = TRUE)
    if (n_bad > 0)
      message("SCHEMA WARNING: hhsize differs from person-record count for ",
              n_bad, " rows (incomplete roster?)")
  }
  if ("age" %in% names(df) && any(df$age < 0 | df$age > 120, na.rm = TRUE))
    fail("age outside 0-120")
  if ("male" %in% names(df) && !all(df$male %in% c(0, 1, NA)))
    fail("male must be 0/1 or missing")
  if ("educat4" %in% names(df) && !all(df$educat4 %in% c(1:4, NA)))
    fail("educat4 outside 1-4")
  if ("empstat" %in% names(df) && !all(df$empstat %in% c(1:4, NA)))
    fail("empstat outside 1-4")

  message("50by35 schema validation PASSED (", nrow(df), " observations)")
  invisible(TRUE)
}
