# COLLAPSE DATA TO MUNICIPALITY LEVEL TO ADD AS CONTROLS IN REGRESSIONS

# PACKAGES
library(haven)
library(tidyverse)
library(data.table)
library(dtplyr) # Requires old version 0.0.3; code breaks with 1.0.0
  # Install with remotes::install_version("dtplyr", version = "0.0.3", repos = "http://cran.us.r-project.org")
library(magrittr)
library(here)

# FUNCTIONS
source(here::here("scripts", "myfunctions.R")) # includes tabulator

# PRELIMINARIES
Sys.time() %>% print() # note log is automatic with R CMD BATCH

# DATA
cpix_baseline <- readRDS(here::here("proc", "cpix_baseline.rds")) # enoe_convert.R
cpix_baseline # Take a look

cpix_baseline[, municipio := str_c(cve_ent, cve_mun)]

cpix_baseline[precio == 0, .N] # only 2 obs out of 10million have precio==0, let them be NA
cpix_baseline[is.na(precio), .N] # check if any are missing price

cpix_baseline[, log_precio := log(precio)]

price_vars <- cpix_baseline %>% select_colnames("precio")
cpix_baseline_mun <- cpix_baseline[, lapply(.SD, mean, na.rm = TRUE), 
  by = "municipio",
  .SDcols = price_vars
]
cpix_baseline_mun[, .N] # make sure it worked

# Log of mean price (not same as mean of log wage)
cpix_baseline_mun[, log_mean_precio := log(precio)]

# SAVE
cpix_baseline_mun %>% saveRDS(here::here("proc", "cpix_baseline_mun.rds"))
cpix_baseline_mun %>% write_dta(here::here("proc", "cpix_baseline_mun.dta"))

# WRAP UP
warnings() %>% print()
Sys.time() %>% print()
