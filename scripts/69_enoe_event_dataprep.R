# DATA PREP FOR EVENT STUDY OF EFFECT OF PROSPERA EXPANSION ON WAGES
#  _all indicates that it's all sectors (not just corner store employees)

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
source(here::here("scripts", "myfunctions.R"))

# PRELIMINARIES
Sys.time() %>% print() # log is automatic with R CMD BATCH

# DATA
enoe <- readRDS(here::here("proc", "enoe_all.rds")) %>% tbl_dt() # enoe_convert.R

enoe[, municipio := str_pad(cod_municipality, width = 5, pad = "0")]

# Merge with 
iter_mun <- readRDS(here::here("proc", "iter_mun.rds"))
cards_mun <- readRDS(here::here("proc", "cards_mun.rds")) %>% tbl_dt() # was data.table
cards_mun %<>% select(municipio, debit_cards, debit_cards_instant, bimswitch)

enoe %<>% left_join(iter_mun, by = "municipio")
enoe %<>% left_join(cards_mun, by = "municipio")

# Keep urban only
enoe %>% tabcount(municipio) # 1650
enoe[has_urban == 1] %>% tabcount(municipio) # 521
enoe <- enoe[has_urban == 1]

# Note: the CNBV vars are measured for the quarter; create key (not perfect since 4 quarters, 6 bimesters)
bim_quarter <- tribble(
  ~bim_switch, ~quarter_switch,
  "1", 1,
  "2", 1, # really half-half between 1st quarter 2nd
  "3", 2,
  "4", 2, # really half-half between 2nd quarter (06) and 3rd (09)
  "5", 3, 
  "6", 4
) %>% tbl_dt() # note this is the same key as in cnbv_eventstudy.R, where CNBV data is also by quarter

enoe[, ":="(
  year_switch = str_sub(bimswitch, 1, 4),  
  bim_switch = str_sub(bimswitch, 5, 5)
)]
enoe %>% tab(bim_switch)
enoe %>% tab(year_switch)

# Prepare for event study
enoe[, year_quarter := str_c(year, quarter)]
enoe %>% tab(year_quarter)
enoe %<>% left_join(bim_quarter, by = "bim_switch")
enoe[, quarterswitch := str_c(year_switch, quarter_switch)]

enoe %<>% merge_key("year_quarter", "quarterswitch", n_periods = 4, 
  newvars = c("yearquarter_key", "quarterswitch_key"))
enoe[, period_since_switch := yearquarter_key - quarterswitch_key]
enoe %>% tab(period_since_switch)
  # can do -2 to 12 with 270 of the 277; 
  # can do what I have in paper -6 (1.5y) to 12 with 176 locs

# Code control as -1 since this is omitted period
enoe[, period_since_switch := ifelse(
  !is.na(bimswitch), period_since_switch, -1) %>% 
  as.factor() %>% relevel(ref = "-1")
]
enoe %>% tab(period_since_switch)

# Define treatment (same as in other event study files)
enoe[, treat := ifelse(is.na(bimswitch), 0, ifelse(
  (year_switch < 2012) | (year_switch == 2012 & bim_switch < 4), 1, NA))]

# Check how many missing wage
enoe[is.na(wage), .N]/enoe[, .N] # 69%
  # note this is normal since I didn't restrict the sample at all
  # 51% don't work
# Check if 0s
assert_that(enoe[wage == 0, .N] == 0) # none with 0 wage

# Restrict to those with non-missing wage
enoe <- enoe[!is.na(wage)]

# Create logs
wage_vars <- enoe %>% select_colnames("wage")
log_wage_vars <- wage_vars %>% map_chr(function(x) str_c("log_", x))
enoe[, (log_wage_vars) := lapply(.SD, log), .SDcols = wage_vars] # don't need to use log1p since no log

enoe %>% saveRDS(here::here("proc", "enoe_cards_all.rds")) # all sectors

# WRAP UP
warnings() %>% print()
Sys.time() %>% print()

