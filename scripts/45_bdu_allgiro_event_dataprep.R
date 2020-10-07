# DATA PREP FOR POS ADOPTION EVENT STUDY 
#  Sean Higgins

# PACKAGES
library(data.table)
library(tidyverse)
library(dtplyr) # Requires old version 0.0.3; code breaks with 1.0.0
  # Install with remotes::install_version("dtplyr", version = "0.0.3", repos = "http://cran.us.r-project.org")
library(magrittr)
library(assertthat)
library(haven)
library(here)

# FUNCTIONS
source(here::here("scripts", "myfunctions.R"))

# PRELIMINARIES
Sys.time() %>% print() # log automatic with R CMD BATCH

# DATA
bdu_loc_long <- readRDS(here::here("proc", "bdu_loc_long_allgiro.rds"))
bdu_cp_long  <- readRDS(here::here("proc", "bdu_cp_long_allgiro.rds"))

# At bimester rather than month level
#  since it's stock, just use even months
bdu_prep <- function(dt) {
  dt <- dt[as.numeric(month) %% 2 == 0]
  dt[, bim := as.character(as.numeric(month)/2)]
  dt[, year_bim := str_c(year, bim)]
  # Outcome variable: log(POS + 1)
  dt[, ln_pos := log1p(pos)]
  dt
}
bdu_loc_long %<>% bdu_prep()
bdu_cp_long %<>% bdu_prep()

# Merge in bimswitch
cards_pob <- readRDS(here::here("proc", "cards_pob.rds"))
cards_pob %<>% tbl_dt() %>% select(localidad, contains("switch"))

bdu_merge <- function(dt) {
  new_dt <- dt %>% left_join(cards_pob, by = "localidad")
  new_dt %<>% merge_key("year_bim", "bimswitch", n_periods = 6, 
    newvars = c("year_bim_key", "bimswitch_key")  
  )
  new_dt[, bim_since_switch := 
    ifelse(!is.na(bimswitch), year_bim_key - bimswitch_key, -1) %>% 
    # since -1 is omitted period, put control as -1 so that they
    # have 0 for all the interaction dummies included
    as.factor() %>% relevel(ref = "-1")
    # as.factor for the regression dummies; relevel to omit k=-1
  ]
  new_dt[, treat := ifelse(is.na(bimswitch), 0, ifelse(
    (year_switch < 2012) | (year_switch == 2012 & bim_switch < 4), 1, NA)
  )]
  new_dt
}

bdu_loc_bim <- bdu_merge(bdu_loc_long)
bdu_cp_bim <- bdu_merge(bdu_cp_long)

# Take a look:
bdu_loc_bim %>% tab(bim_since_switch) %>% print(n = Inf)
bdu_loc_bim %>% print()
bdu_loc_bim %>% tab(bimswitch) %>% print(n = Inf)
bdu_loc_bim %>% tab(treat) %>% print()

# Winsorize at 5% level
bdu_loc_bim %<>% winsorize(outcome = "pos", newvar = "pos_w", 
  by = c("treat", "year_bim"), highonly = TRUE)
bdu_cp_bim %<>% winsorize(outcome = "pos", newvar = "pos_w", 
  by = c("treat", "year_bim"), highonly = TRUE)

# Merge with ITER to restrict to urban
iter <- readRDS(here::here("proc", "iter2010.rds"))
restrict_urban <- function(dt) {
  new_dt <- dt %>% left_join(iter, by = "localidad")
  new_dt <- new_dt[pobtot > 15000]
}
bdu_loc_bim_urban <- restrict_urban(bdu_loc_bim)
bdu_cp_bim_urban <- restrict_urban(bdu_cp_bim)

# Wide version for locality level regressions
bdu_wide <- bdu_loc_bim_urban %>% 
  select(localidad, year, bim, pos, ln_pos) %>% 
  dcast(localidad ~ year + bim, value.var = c("pos", "ln_pos"))

# SAVE
bdu_loc_bim_urban %>% saveRDS(here::here("proc", "bdu_loc_allgiro_forreg.rds"))
bdu_cp_bim_urban %>% saveRDS(here::here("proc", "bdu_cp_allgiro_forreg.rds"))
bdu_wide %>% saveRDS(here::here("proc", "bdu_loc_allgiro_wide.rds"))
bdu_wide %>% write_dta(here::here("proc", "bdu_loc_allgiro_wide.dta"))

# WRAP UP
warnings() %>% print()
Sys.time() %>% print()

