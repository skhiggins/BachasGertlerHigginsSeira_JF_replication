# PREPARE MICRO CPI DATA FOR EVENT STUDY

# PACKAGES #
library(tidyverse)
library(data.table)
library(dtplyr) # Requires old version 0.0.3; code breaks with 1.0.0
  # Install with remotes::install_version("dtplyr", version = "0.0.3", repos = "http://cran.us.r-project.org")
library(magrittr)
library(assertthat)
library(here)

# FUNCTIONS #
source(here::here("scripts", "myfunctions.R"))

# PRELIMINARIES
Sys.time() %>% print() # note log is automatic with R CMD BATCH

# DATA
# Micro-CPI data:
cpix <- readRDS(here::here("proc", "cpix.rds"))
# Prospera card rollout:
cards_mun <- readRDS(here::here("proc", "cards_mun.rds")) # cards_panel.R
cards_mun <- cards_mun[, c("municipio", "debit_cards", "fams", "bimswitch", "in_cards")] # only necessary columns
# Municipality populations
iter_mun <- readRDS(here::here("proc", "iter_mun.rds")) # iter_dataprep.R 

# Municipality code
cpix[, municipio := str_c(cve_ent, cve_mun)]

# Combine to bimester level
cpix[, bim := ceiling(month/2)]
collapse_cols <- setdiff(names(cpix), c("month", "month_id", "precio"))
cpix_bim <- cpix[, lapply(.SD, mean), .SDcols = "precio", by = collapse_cols]

cpix_bim %<>% merge(iter_mun, by = "municipio", all.x = TRUE)
assert_that(all(cpix_bim$in_iter==1))
cpix_bim[, in_iter := NULL]
cpix_bim %<>% merge(cards_mun, by = "municipio", all.x = TRUE)

cpix_bim %>% tab(in_cards) # not surprising that most (92%) included in card rollout
  # since the price data is focused on cities, and card rollout was in urban areas

# Create bimesters since switch variable
cpix_bim[, year_bim := str_c(year, bim)]
year_bim_key <- data.table(sort(unique(cpix_bim$year_bim)), 
  1:length(unique(cpix_bim$year_bim)))
names(year_bim_key) <- c("year_bim", "bim_key")

cpix_bim %<>% merge(year_bim_key, by.x = "bimswitch", by.y = "year_bim", all.x = TRUE)
cpix_bim[, ":="(bim_switch_key = bim_key, bim_key = NULL)] # rename
cpix_bim %<>% merge(year_bim_key, by = "year_bim", all.x = TRUE)

# Periods since switch
cpix_bim[, bim_since_switch := bim_key - bim_switch_key]

cpix_bim %>% tab(bim_since_switch)

# Code control as -1 since this is omitted period (but for main results where I exclude pure control this doesn't matter)
cpix_bim[, bim_since_switch := ifelse(
  !is.na(bimswitch), bim_since_switch, -1) %>% 
  as.factor() %>% relevel(ref = "-1")
]
cpix_bim %>% tab(bim_since_switch)

# Log price variable
# Check for 0s
cpix_bim[precio==0, .N] # only 2 obs out of 10million have precio==0, let them be NA
cpix_bim[, ln_price := log(precio)] 

# Fixed effects
#  Make sure stores always in same loc
cpix_bim %>% tabcount(clave) # not sure what clave is
cpix_bim %>% tabcount(barcode_id) # this is the barcode-equivalent product fixed effect
cpix_bim %>% tabcount(trajectory_id) # these are the good x store fixed effects they use
  # 441k (this is the actual FE Atkin et al use but not sure exactly how they created it)

cpix_bim[, good_store := .GRP, by = c("clave", "barcode_id")]
cpix_bim %>% tabcount(good_store)
  # 448k, close to 441k from trajectory_id

# Treatment variables
cpix_bim[, ":="(
  year_switch = str_sub(bimswitch, 1, 4) %>% as.numeric(),
  bim_switch = str_sub(bimswitch, 5, 5) %>% as.numeric()
)]
cpix_bim[, treat := ifelse(is.na(bimswitch), 0, ifelse(
  (year_switch < 2012) | (year_switch == 2012 & bim_switch < 4), 1, NA))]
cpix_bim[, D_jt := ifelse(treat == 1, (bim_key - bim_switch_key >= 0), 0)]

# SAVE
cpix_bim %>% saveRDS(here::here("proc", "cpix_bim.rds"))

# WRAP UP
warnings() %>% print()
Sys.time() %>% print()

