# NUMBER OF CARDS EVENT STUDY PRE-TRENDS
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

# FUNCTIONS
source(here::here("scripts", "myfunctions.R"))

############################################################################################
# DATA
cnbv_urb_full <- readRDS(here::here("proc", "cnbv_forreg.rds"))

###########################################################################################
# RESULTS
outcomes <- c("ln_cards_all", "ln_atm_number", "ln_branch_number")

# Formatting
ylabel <- seq(-0.2, 0.4, by = 0.1)

cnbv_urb_full[(year < 2017) & treat==1, (N_loc = .N), by = "period_since_switch"]
  # 154 in -6, only 69 if you go 6 months further back (in case they ask)
  # 255 from -1 on

# Pre-trends; can only go back 2 years since data starts end 2008
#  and nearly all of rollout had occurred by end of 2010
the_titles <- list(
  "Log debit and credit cards", 
  "Log ATMs", 
  "Log bank branches"
)

i <- 0
for (outcome in outcomes) {
  i <- i + 1
  
  if (outcome == "ln_branch_number") { # left panel
    x_title_color = "white"
    y_text_color = "black"
  } else if (outcome == "ln_atm_number") {
    x_title_color = "black"
    y_text_color = "white"
  } else if (outcome == "ln_cards_all") {
    x_title_color = "white"
    y_text_color = "white"
  } else { # not included in figure
    x_title_color = "black"
    y_text_color = "black"    
  }
    
  my_theme <- set_theme(16, y_title_size = NA,
    x_title_margin = "t = 10",
    y_text_color = y_text_color,
    x_title_color = x_title_color # only visible on middle panel
  )    
  
  binned_event_study(
    bin_at = c(-8, 8), 
    df = cnbv_urb_full[year < 2017],
    control = FALSE, 
    period_since_switch = "period_since_switch",
    i_unit = "municipio",
    t_unit = "period",
    months_per_period = 3, label_by = 4,
    y_cutoffs = rep(list(c(-0.42, 0.42)), 6),
    y_breaks = rep(list(seq(-0.4, 0.4, by = 0.1)), 6), 
    y_accuracy = 0.1, # because seq(-0.3, 0.3, by = 0.1) getting floating point rounding issue
    outcomes = outcome,
    suffix = "_pre", 
    pre = TRUE, 
    error_size = 0.5, # more visible for small panel graphs
    error_width = 0.4, # more visible for small panel graphs
    point_stroke = 0.75,
    width = 4, 
    height = 4,
    x_expand = c(0.01, 0.01), 
    titles = the_titles[[i]],
    xtitle = "Months relative to switch to cards"
  )
}

# WRAP UP
warnings() %>% print()
Sys.time() %>% print()

