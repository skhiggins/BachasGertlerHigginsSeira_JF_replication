# COLLAPSE DATA TO MUNICIPALITY LEVEL TO ADD AS CONTROLS IN REGRESSIONS

# PACKAGES
library(haven)
library(tidyverse)
library(data.table)
library(dtplyr) # Requires old version 0.0.3; code breaks with 1.0.0
  # Install with remotes::install_version("dtplyr", version = "0.0.3", repos = "http://cran.us.r-project.org")
library(magrittr)
library(assertthat)
library(here)

# FUNCTIONS
source(here::here("scripts", "myfunctions.R")) # includes tabulator

# PRELIMINARIES
Sys.time() %>% print() # note log is automatic with R CMD BATCH

# DATA
enoe_baseline <- readRDS(here::here("proc", "enoe_baseline.rds")) # enoe_convert.R
enoe_baseline # Take a look

# Lots of missing wages; note from enoe_explore.R about 25% of sample has missing for 
#  "did you work in last week?" and another 35% did not work.
enoe_baseline %>% tab(employed)
enoe_baseline %>% tab(p1) # p1 is whether worked in last week
enoe_baseline[employed == 0] %>% tab(subsector)
enoe_baseline[, missing_wage := is.na(wage)]
enoe_baseline[employed == 0] %>% tab(missing_wage) # 98%
  # others due to more extensive definition of whether working than I used?

enoe_baseline[, log_wage := log(wage)] # note no wage=0 obs

# Collapse to municipality level
enoe_baseline %<>% rename(municipio = cod_municipality)
  # so that it matches other data sets
wage_vars <- enoe_baseline %>% select_colnames("wage")
mean_wage_vars <- wage_vars %>% map_chr(~ str_c("mean_", .x))
enoe_baseline[, .N]
enoe_baseline_mun <- enoe_baseline[, lapply(.SD, mean, na.rm = TRUE), 
  by = "municipio", 
  .SDcols = wage_vars
]
enoe_baseline_mun[, .N] # to make sure it worked

# Some had all missing wage within a locality, so those have missing mean wage for loc:
assert_that(
  enoe_baseline_mun[is.na(wage), .N] == 
  enoe_baseline_mun[is.na(wage) & missing_wage == 1, .N]
)
# Drop those
enoe_baseline_mun <- enoe_baseline_mun[!is.na(wage)]

# Log of mean wage (not same as mean of log wage)
enoe_baseline_mun[, log_mean_wage := log(wage)]

# Change municipio to a string variable
enoe_baseline_mun[, municipio := str_pad(municipio, width = 5, pad = "0")]

# SAVE
enoe_baseline_mun %>% saveRDS(here::here("proc", "enoe_baseline_mun.rds"))
enoe_baseline_mun %>% write_dta(here::here("proc", "enoe_baseline_mun.dta"))

# WRAP UP
warnings() %>% print()
Sys.time() %>% print()
