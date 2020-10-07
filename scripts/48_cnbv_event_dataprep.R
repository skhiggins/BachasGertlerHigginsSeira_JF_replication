# DATA PREP FOR EVENT STUDY OF EFFECT OF PROSPERA EXPANSION ON NUMBER OF CARDS
#  Sean Higgins

# PACKAGES
library(tidyverse)
library(data.table)
library(dtplyr) # Requires old version 0.0.3; code breaks with 1.0.0
  # Install with remotes::install_version("dtplyr", version = "0.0.3", repos = "http://cran.us.r-project.org")
library(magrittr)
library(assertthat)
library(here)

# PRELIMINARIES
Sys.time() %>% print() # log is automatic with R CMD BATCH
combine <- 1 # manually combine the municipalities where there was 
  # clearly a data entry error (13048 and 13051)
  # because 13048 loses about 100k cards in same period 13051 gains 100k cards
  # (note both are listed as Pachuca in raw data)

# FUNCTIONS
source(here::here("scripts", "myfunctions.R"))

############################################################################################
# DATA

# CNBV data on number of cards
cnbv_mun <- readRDS(here::here("proc", "cnbv_mun.rds"))
cnbv_mun %>% class() # data.table

if (combine) {
  cnbv_mun[, municipio := ifelse(municipio == "13051", "13048", municipio)]
  cnbv_mun <- cnbv_mun[, lapply(.SD, sum), by = c("municipio", "cve_periodo", "year", "month")]
}

cnbv_mun[, period := str_c(cve_periodo)]
# recode the problem period
cnbv_mun[, period := ifelse(period == "201104", "201103", period)]
  
cnbv_mun[, ":="(
  year = str_sub(period, 1, 4),
  month = str_sub(period, 5, 6)
)] # replacing it due to change above
cnbv_mun <- cnbv_mun[month %in% c("03", "06", "09", "12")]
  # since changes from by quarter to by six-month, 
  # and quarters don't line up cleanly with rollout (since I don't know when cards received
  #  in first vs second month)
cnbv_mun[, in_cnbv := 1] # for merge

# Population from ITER (iter_dataprep.R)
iter_mun <- readRDS(here::here("proc", "iter_mun.rds"))

if (combine) {
  iter_mun[, municipio := ifelse(municipio == "13051", "13048", municipio)]
  iter_mun <- iter_mun[, lapply(.SD, sum), by = c("municipio", "has_urban", "in_iter")]
}

# Prospera card rollout
cards_mun <- readRDS(here::here("proc", "cards_mun.rds"))

# Merge
cnbv_mun %<>% merge(iter_mun, by = "municipio", all = TRUE)
assert_that(all(cnbv_mun$in_cnbv==1)) # check merge
cnbv_mun %>% tab(in_iter) # few NAs
cnbv_mun[is.na(in_iter)] %>% distinct(municipio) # blank, 23010 or 23011
cnbv_mun <- cnbv_mun[!is.na(in_iter)]
cnbv_mun[, in_iter := NULL]

# Keep urban only
cnbv_mun %>% tabcount(municipio) # 2456
cnbv_mun[has_urban == 1] %>% tabcount(municipio) # 521
cnbv_urb <- cnbv_mun[has_urban == 1]
cnbv_urb %<>% select(municipio, period, year, month, everything())

# Balance out the panel
cnbv_urb %<>% setorder(municipio, period) %>% setkey(municipio, period)
cnbv_urb_full <- cnbv_urb[CJ(municipio, period, unique = TRUE)]
cnbv_urb_full %<>% tbl_dt()

# Re-merge constant (within mun) vars
cnbv_urb_full %<>% select(-has_urban, -pobtot)
cnbv_urb_full %<>% left_join(iter_mun, by = "municipio")
assert_that(cnbv_urb_full[is.na(pobtot), .N] == 0)

# Merge with bimswitch from Prospera data
cnbv_urb_full %<>% mutate(in_cnbv = 1)
cards_mun %<>% tbl_dt() %>% select(-pobtot) # so that not duplicating
cnbv_urb_full %<>% left_join(cards_mun, by = "municipio") 
  # all.y = FALSE because cnbv already urban,
  # while cards_mun still includes all mun

# subset that existed in 200812
cnbv_200812 <- cnbv_urb_full[period == "200812"] %>% select(municipio, bimswitch)
cnbv_201103 <- cnbv_urb_full[period == "201103"] %>% select(municipio, bimswitch)

# Note: the CNBV vars are measured for the quarter; create key (not perfect since 4 quarters, 6 bimesters)
bim_quarter <- tribble(
  ~bim_switch, ~quarter_switch,
  "1", "03",
  "2", "03", # really half-half between 1st quarter (03) and 2nd (06)
  "3", "06",
  "4", "06", # really half-half between 2nd quarter (06) and 3rd (09)
  "5", "09", 
  "6", "12"
)

# Prepare for event study
year_period_key <- data.table(sort(unique(cnbv_urb_full$period)), 
  1:length(unique(cnbv_urb_full$period)))
names(year_period_key) <- c("period", "period_key")
cnbv_urb_full[, ":="(year_switch = str_sub(bimswitch, 1, 4), bim_switch = str_sub(bimswitch, 5, 5))]

cnbv_urb_full %<>% merge(bim_quarter, by = "bim_switch", all = TRUE)
assert_that(cnbv_urb_full[is.na(municipio), .N] == 0)
assert_that(all(cnbv_urb_full$in_cnbv == 1))

# Check number of localities by period
tot_loc <- cnbv_201103 %>% nrow()
assert_that(all(cnbv_urb_full[, .N, by = "period"][, "N"] == tot_loc))
cnbv_urb_full[!is.na(bimswitch), .N, by = "period"]
tot_loc_T <- cnbv_201103[!is.na(bimswitch)] %>% nrow()
assert_that(all(cnbv_urb_full[!is.na(bimswitch), .N, by = "period"][, "N"] == tot_loc_T))

# Periods since switch
cnbv_urb_full[, quarterswitch := str_c(year_switch, quarter_switch)]
cnbv_urb_full %<>% merge(year_period_key, by.x = "quarterswitch", by.y = "period", all.x = TRUE)
cnbv_urb_full[, quarterswitch_key := period_key]
cnbv_urb_full[, period_key := NULL]
cnbv_urb_full %<>% merge(year_period_key, by.x = "period", by.y = "period", all.x = TRUE)
  # and now leave it named period_key

# do it simplest first and look at tab
cnbv_urb_full[, period_since_switch := period_key - quarterswitch_key]
cnbv_urb_full %>% tab(period_since_switch)
  # can do -2 to 12 with 270 of the 277; 
  # can do what I have in paper -6 (1.5y) to 12 with 176 locs

# Code control as -1 since this is omitted period
cnbv_urb_full[, period_since_switch := ifelse(
  !is.na(bimswitch), period_since_switch, -1) %>% 
  as.factor() %>% relevel(ref = "-1")
]
cnbv_urb_full %>% tab(period_since_switch)

cnbv_200812 %<>% select(municipio) %>% 
  mutate(in_08 = 1)
cnbv_urb_full %<>% merge(cnbv_200812, by = "municipio")

cnbv_urb_full %>% tab(quarterswitch_key)

# Create additional card variables
cnbv_urb_full[, ":="(cards_all = cards_debit + cards_credit)]
card_vars <- cnbv_urb_full %>% select_colnames("cards_")
number_vars <- cnbv_urb_full %>% select_colnames("_number")
all_outcome_vars <- c(card_vars, number_vars)
ln_outcome_vars <- all_outcome_vars %>% map_chr(function(x) str_c("ln_", x))
cnbv_urb_full[, (ln_outcome_vars) := lapply(.SD, log1p), .SDcols = all_outcome_vars] 

cnbv_urb_full[period_since_switch == "-1", mean(debit_cards, na.rm = TRUE)]
cnbv_urb_full[period_since_switch == "-1"] %>% quantiles(debit_cards, na.rm = TRUE)
  # average: 3942 cards; median 2186 cards from Prospera
cnbv_urb_full[period_since_switch == "-1", mean(cards_debit, na.rm = TRUE)]
  # not too different, slightly lower as expected since NA-->0
cnbv_urb_full[period_since_switch == "-1"] %>% quantiles(cards_debit, na.rm = TRUE)
  # for comparison: median # households is about 7700

# Define treatment (same as in bdu_altas_eventstudy_bin.R for POS adoption)
cnbv_urb_full[, treat := ifelse(is.na(bimswitch), 0, ifelse(
  (year_switch < 2012) | (year_switch == 2012 & bim_switch < 4), 1, NA))]

# winsorized variables in levels
for (var in all_outcome_vars) {
  newvar <- str_c(var, "_w")
  cnbv_urb_full %<>% winsorize(outcome = var, newvar = newvar, by = c("treat", "period"), 
    highonly = TRUE, na.rm = TRUE  
  )
}

cnbv_urb_full[, year := str_sub(period, 1, 4)]

# SAVE
cnbv_urb_full %>% saveRDS(here::here("proc", "cnbv_forreg.rds"))

# WRAP UP
warnings() %>% print()
Sys.time() %>% print()
