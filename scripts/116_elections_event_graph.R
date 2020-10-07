# EVENT STUDY OF POLITICAL PARTY IN POWER

# PACKAGES
library(data.table)
library(tidyverse)
library(dtplyr) # Requires old version 0.0.3; code breaks with 1.0.0
  # Install with remotes::install_version("dtplyr", version = "0.0.3", repos = "http://cran.us.r-project.org")
library(magrittr)
library(assertthat)
library(here)

# FUNCTIONS
source(here::here("scripts", "myfunctions.R"))

# DATA
elections <- readRDS(here::here("proc", "elections_forreg.rds"))

# Event study
my_theme <- set_theme()
binned_event_study(
  bin_at = c(-3, 3), 
  df = elections, # because new president in 2013; rollout over 
  control = FALSE, 
  period_since_switch = "year_since_switch",
  xtitle = "Years since card shock",
  i_unit = "municipio",
  t_unit = "year_",
  months_per_period = 1, label_by = 1,
  error_width = 0.1,
  y_cutoffs = list(c(-.4, .4)), 
  y_breaks  = list(seq(-0.4, 0.4, by = 0.2)),
  y_expand = c(0, 0),
  outcomes = c("partido_pan")
)
  