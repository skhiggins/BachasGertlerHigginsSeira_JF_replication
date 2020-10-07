# MEANS OF POS PER MONTH BY POSTAL CODE
#  Sean Higgins

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

# PRELIMINARIES
# Control Center
tosink <- 1 # set to 0 to display output in console;
  # set to 1 to store results in a log file

# DATA
# By giro (sector), just read in top 3 for efficiency:
bdu_cp_month <- readRDS(here::here("proc", "bdu_cp_month_urban.rds"))

# All giro
proj <- "bdu_cp_month_means_allgiro"
if (tosink) {
  options(width = 10000, max.print = 10000)
  sink(
    here::here("logs", str_c(proj, time_stamp(), ".log")),
    append = FALSE,
    split = FALSE
  )
}   

bdu_cp_month[, yy := str_sub(year, 3, 4)] # for shorter cols

bdu_cp_month_all <- bdu_cp_month[, .(cum_new_pos = sum(cum_new_pos)), 
  by = c("cp", "yy", "month")  
] # sum within postal code-month across all giros

altas_wide_all <- bdu_cp_month_all %>% 
  data.table::dcast(cp ~ yy + month, value.var = "cum_new_pos")

n_cp_all <- altas_wide_all %>% tabcount(cp)
print("N CP all")
n_cp_all %>% print()

print("all giro averages")
i <- 1
while (i < n_cp_all) {
  j <- i + 49
  altas_wide_all[i:min(j, n_cp_all)] %>% print_all()
  i <- i + 50
}  

if (tosink) sink()

# Corner and super
proj <- "bdu_cp_month_means_CS"
if (tosink) {
  options(width = 10000, max.print = 10000)
  sink(
    here::here("logs", str_c(proj, time_stamp(), ".log")),
    append = FALSE,
    split = FALSE
  )
}   

bdu_cp_month[, yy := str_sub(year, 3, 4)] # for shorter cols

bdu_cp_month_C <- bdu_cp_month[giro == 5499] # corner stores

altas_wide_C <- bdu_cp_month_C %>% 
  data.table::dcast(cp ~ yy + month, value.var = "cum_new_pos")

bdu_cp_month_S <- bdu_cp_month[giro == 5411] # supermarkets

altas_wide_S <- bdu_cp_month_S %>% 
  data.table::dcast(cp ~ yy + month, value.var = "cum_new_pos")

n_cp_C <- altas_wide_C %>% tabcount(cp)
print("N CP C")
n_cp_C %>% print()
n_cp_S <- altas_wide_S %>% tabcount(cp)
print("N CP S")
n_cp_S %>% print()

print("corner store averages")
i <- 1
while (i < n_cp_C) {
  j <- i + 49
  altas_wide_C[i:min(j, n_cp_C)] %>% print_all()
  i <- i + 50
}

print("supermarket averages")
i <- 1
while (i < n_cp_S) {
  j <- i + 49
  altas_wide_S[i:min(j, n_cp_S)] %>% print_all()
  i <- i + 50
}

if (tosink) sink()
