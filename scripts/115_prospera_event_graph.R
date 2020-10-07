# EVENT STUDY OF NUMBER OF BENEFICIARIES

############
# PACKAGES #
############
library(data.table)
library(tidyverse)
library(dtplyr) # Requires old version 0.0.3; code breaks with 1.0.0
  # Install with remotes::install_version("dtplyr", version = "0.0.3", repos = "http://cran.us.r-project.org")
library(magrittr)
library(assertthat)
library(here)

#############
# FUNCTIONS #
#############
source(here::here("scripts", "myfunctions.R"))

# PRELIMINARIES
start_year <- 2007

########
# DATA #
########
cards_combined <- readRDS(here::here("proc", "prospera_forreg.rds"))

min_period <- cards_combined[year >= start_year & treat==1] %$% min(fac_to_num(year_since_switch))
max_period <- cards_combined[year >= start_year & treat==1] %$% max(fac_to_num(year_since_switch))
my_theme <- set_theme()
binned_event_study(
  cut_off = c(-8, 7),
  bin_at = c(-3, 3), 
  df = cards_combined[year >= start_year], 
  outcomes = "ln_fams_w", 
  control = FALSE, 
  y_cutoffs = list(c(-.4, .4)), 
  y_breaks  = list(seq(-0.4, 0.4, by = 0.2)),
  months_per_period = 1,
  period_since_switch = "year_since_switch",
  xtitle = "Years since card shock", 
  label_by = 1, 
  y_accuracy = 0.1,
  y_expand = c(0, 0), # expansion(mult = c(0.0001, 0)),
  error_width = 0.1
)

