# POS ADOPTION EVENT STUDY PRE-TRENDS
#  Sean Higgins

# PACKAGES
library(data.table)
library(tidyverse)
library(dtplyr) # Requires old version 0.0.3; code breaks with 1.0.0
  # Install with remotes::install_version("dtplyr", version = "0.0.3", repos = "http://cran.us.r-project.org")
library(magrittr)
library(lfe)
library(assertthat)
library(here)

# FUNCTIONS
source(here::here("scripts", "myfunctions.R"))

# PRELIMINARIES
Sys.time() %>% print() # log is automatic with R CMD BATCH

# DATA
bdu_cp_bim <- readRDS(here::here("proc", "bdu_cp_allgiro_forreg.rds")) # bdu_allgiro_eventstudy_dataprep.R

################
# pre-trends for all POS
my_theme <- set_theme(16, y_title_size = NA, 
  y_text_color = "white", # for panel graph  
  x_title_color = "white", # only visible on middle panel
  x_title_margin = "t = 10"
)

binned_event_study(
  cut_off = c(-24, 18), 
  bin_at = c(-18, 12), # same period as other results in debit cards paper 
                       #  (note it's measured in 2-month periods)
  df = bdu_cp_bim, 
  control = FALSE, 
  i_unit = "cp",
  cluster = "localidad",
  months_per_period = 2, 
  outcomes = "ln_pos", 
  y_cutoffs = c(-0.1, 0.1),
  y_breaks = seq(-0.1, 0.1, by = 0.1),
  suffix = "_pre", 
  pre = TRUE,
  error_size = 0.5,
  error_width = 0.4,
  point_stroke = 0.75,
  width = 4,
  height = 4,
  x_expand = c(0.01, 0.01),
  titles = "Log POS terminals"
) 

# WRAP UP
warnings() %>% print()
Sys.time() %>% print()

