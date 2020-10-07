# ADOPTION OF POS TERMINALS: DATA PREP USING BDU DATA SET
# Sean Higgins

# PACKAGES
library(data.table)
library(tidyverse)
library(magrittr)
library(lubridate)
library(assertthat)
library(here)

# FUNCTIONS
source(here::here("scripts", "myfunctions.R"))

# PRELIMINARIES
# Control Center
tosink <- 1  # set to 0 to display output in console;
  # set to 1 to store results in a log file

# LOG
logname <- "bdu_cp_dataprep"
if (tosink) {
  sink(here::here("logs", str_c(logname, time_stamp(), ".log")),
   append = FALSE,
   split = FALSE
  ) #log output
  Sys.time() %>% print()
}

# DATA
bdu_hist <- readRDS(here::here("proc", "bdu_hist.rds")) # bdu_hist.R

#  Keep only the necessary columns for efficiency
bdu_hist <- bdu_hist[, c("cp", "date", "movimiento", "giro")]

# Restrict BDU historico to "nuevo negocio", "recontratacion", "reactivacion"
bdu_altas <- bdu_hist[movimiento %in% c("AL", "RE", "RA")]
bdu_altas[, ':='(
  month = month(date),
  year = year(date)
)]
bdu_altas[, bim := ceiling(month/2)]

# COLLAPSE BY CP, MCC, BIMESTER
bdu_altas_by_cp_mcc <- bdu_altas[,
  list(new_pos = .N),
  by = list(cp, giro, year, bim)
]
print("tab(new_pos)")
bdu_altas_by_cp_mcc %>% tab(new_pos) %>% print()

# ANOTHER VERSION BY CP, MCC, MONTH
bdu_altas_by_cp_mcc_month <- bdu_altas[,
  list(new_pos = .N),
  by = list(cp, giro, year, month)
]

# Also merge in initial number of POS 
bdu_by_cp_mcc_t0 <- readRDS(here::here("proc", "bdu_by_cp_mcc_t0.rds")) 
  # bdu_hist_dataprep.R
bdu_altas_by_cp_mcc %<>% merge(bdu_by_cp_mcc_t0, 
  by = c("cp", "giro"), all.x = TRUE, all.y = FALSE  
)
bdu_altas_by_cp_mcc[, pos_t0 := na_to_0(pos_t0)]
bdu_altas_by_cp_mcc_month %<>% merge(bdu_by_cp_mcc_t0, 
  by = c("cp", "giro"), all.x = TRUE, all.y = FALSE 
)
bdu_altas_by_cp_mcc_month[, pos_t0 := na_to_0(pos_t0)]

# SAVE
bdu_altas_by_cp_mcc %>% saveRDS(here::here("proc", "bdu_altas_by_cp_mcc.rds"))
bdu_altas_by_cp_mcc_month %>% saveRDS(here::here("proc", "bdu_altas_by_cp_mcc_month.rds"))

# CLOSE LOG 
warnings() %>% print()
Sys.time() %>% print()
if (tosink) sink()

