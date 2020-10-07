# CREATE BASELINE CNBV DATA SET
#  Sean Higgins

# PACKAGES
library(tidyverse)
library(data.table)
library(dtplyr) # Requires old version 0.0.3; code breaks with 1.0.0
  # Install with remotes::install_version("dtplyr", version = "0.0.3", repos = "http://cran.us.r-project.org")
library(haven)
library(here)

# FUNCTIONS
source(here::here("scripts", "myfunctions.R")) # includes tabulator

# DATA
cnbv_all <- readRDS(here::here("proc", "cnbv_mun.rds"))

# Save a version with just 200812 to use in the baseline test
#  (Note: 200812 is first period in the CNBV data with the municipality codes present)
cnbv_all_ <- cnbv_all[cve_periodo == "200812"][, c(
  "cve_periodo", "year", "month", "pos_transactions", "pos_number", "atm_transactions", 
  "pos_businesses", "mobile_money") := NULL]

# Create the same vars as in the pre-trends figure to use as controls in other regressions
cnbv_all_[, ":="(cards_all = cards_debit + cards_credit)]
card_vars <- cnbv_all_ %>% select_colnames("cards_")
number_vars <- cnbv_all_ %>% select_colnames("_number")
all_outcome_vars <- c(card_vars, number_vars)
ln_outcome_vars <- all_outcome_vars %>% map_chr(function(x) str_c("log_", x))
cnbv_all_[, (ln_outcome_vars) := lapply(.SD, log1p), .SDcols = all_outcome_vars] 

# SAVE
cnbv_all_ %>% saveRDS(here::here("proc", "cnbv_baseline_mun.rds"))
cnbv_all_ %>% write_dta(here::here("proc", "cnbv_baseline_mun.dta"))
