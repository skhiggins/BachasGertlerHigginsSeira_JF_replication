# MICRO CPI PRICE EVENT STUDY PRE-TRENDS
#  Sean Higgins

############
# PACKAGES #
############
library(lfe)
library(tidyverse)
library(data.table)
library(dtplyr) # Requires old version 0.0.3; code breaks with 1.0.0
  # Install with remotes::install_version("dtplyr", version = "0.0.3", repos = "http://cran.us.r-project.org")
library(magrittr)
library(assertthat)
library(here)

#############
# FUNCTIONS #
#############
source(here::here("scripts", "myfunctions.R"))

############################################################################################
# DATA

cpix_bim <- readRDS(here::here("proc", "cpix_bim.rds"))

cpix_bim[, main_cat := str_sub(aboveclase, 1, 1)]
  
# Restrict to goods that existed since the beginning so that you're not getting results
#  driven by changing basket of goods
bal <- cpix_bim[(main_cat %in% 1) & bim_since_switch == -9][, # -9 is where I'm binning
  .GRP, by = "clave"][, in_bal_clave := 1]
cpix_bim %<>% merge(bal, by = "clave")

my_theme <- set_theme(16, y_title_size = NA,
  y_text_color = "white", # for panel graph,
  x_title_margin = "t = 10"
)

binned_event_study(
  bin_at = c(-18, 12), 
  df = cpix_bim[in_bal_clave==1 & main_cat==1], 
  control = FALSE, 
  fixed_effects = "trajectory_id + year_bim",
  cluster = "municipio",
  t_unit = "year_bim",
  months_per_period = 2, 
  y_cutoffs = c(-0.1, 0.1),
  y_breaks = seq(-0.1, 0.1, by = 0.1),
  y_expand = c(0,0),
  outcomes = "ln_price", 
  suffix = "_pre",
  pre = TRUE,
  error_size = 0.5, # more visible for small panel graphs
  error_width = 0.4, # more visible for small panel graphs
  point_stroke = 0.75,
  width = 4,
  height = 4,
  x_expand = c(0.01, 0.01),
  titles = "Log food prices",
  xtitle = "Months relative to switch to cards"
)
