# Collapse to baseline number of POS by locality (to use as control in cross-section survey regressions)
#  Sean Higgins

# PACKAGES
library(haven)
library(tidyverse)
library(data.table)
library(dtplyr) # Requires old version 0.0.3; code breaks with 1.0.0
  # Install with remotes::install_version("dtplyr", version = "0.0.3", repos = "http://cran.us.r-project.org")
library(magrittr)
library(here)

# FUNCTIONS
source(here::here("scripts", "myfunctions.R"))

# DATA
bdu <- readRDS(here::here("proc", "bdu_loc_long_allgiro.rds"))

bdu_baseline <- bdu[year == "2008" & month == "01"]
bdu_baseline %>% tabcount(localidad) # 1962

bdu_baseline[, log_pos := log(pos + 1)]

# SAVE
bdu_baseline %>% saveRDS(here::here("proc", "bdu_baseline.rds"))
bdu_baseline %>% write_dta(here::here("proc", "bdu_baseline.dta"))
