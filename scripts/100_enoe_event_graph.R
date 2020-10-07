# EVENT STUDY OF EFFECT OF PROSPERA EXPANSION ON WAGES: PRE-TRENDS
#  Sean Higgins

# PACKAGES
library(lfe)
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
Sys.time() %>% print() # log automatic with R CMD BATCH

# Graph formatting
my_theme <- set_theme(16, y_title_size = NA,
  x_title_margin = "t = 10",
  x_title_color = "white" # only visible on middle panel
)

# DATA
enoe <- readRDS(here::here("proc", "enoe_cards_all.rds")) %>% tbl_dt() # enoe_eventstudy_dataprep.R

# REGRESSIONS
# How many times does each mun appear?
enoe %>% tabcount(municipio) # 513
enoe[treat == 1] %>% tabcount(municipio) # 253
enoe_N_time <- enoe[treat == 1, .GRP, by = c("municipio", "year_quarter")][, .(N_time = .N), by = "municipio"] 
enoe_N_time %>%  tab(N_time) %>% print_all() # result: 60% appear in all periods
enoe %<>% left_join(enoe_N_time, by = "municipio")
  # now can use the restriction N_time==48 if want to restrict

# Corner store non-owners: 3 years for debit cards paper
binned_event_study(
  bin_at = c(-12, 8), # since these are quarters
  df = enoe, 
  control = FALSE, 
  period_since_switch = "period_since_switch",
  i_unit = "municipio",
  t_unit = "year_quarter",
  months_per_period = 3, label_by = 4,
  y_cutoffs = c(-0.1, 0.1),
  y_breaks = seq(-0.1, 0.1, by = 0.1),
  y_accuracy = 0.1,
  outcomes = "log_wage",
  suffix = "_pre", 
  pre = TRUE, 
  error_size = 0.5, # more visible for small panel graphs
  error_width = 0.4, # more visible for small panel graphs
  point_stroke = 0.75,
  width = 4, 
  height = 4,
  x_expand = c(0.01, 0.01),
  titles = "Log wage"
)

# WRAP UP
warnings() %>% print()
Sys.time() %>% print()
