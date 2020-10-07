# BDU ACTUAL (TO DETERMINE HOW MANY TERMINALS EXISTED PRE-2006)
  # Goal: get number of terminals by loc x giro x day as of 2006
# Sean Higgins

# PACKAGES
library(data.table)
library(tidyverse)
library(dtplyr) # Requires old version 0.0.3; code breaks with 1.0.0
  # Install with remotes::install_version("dtplyr", version = "0.0.3", repos = "http://cran.us.r-project.org")
library(lubridate)
library(assertthat)
library(here)
 
# FUNCTIONS
source(here::here("scripts", "myfunctions.R"))

# CONTROL CENTER
tosink <- 1

# LOG
if (tosink) {
  if (!dir.exists("logs")) dir.create("logs")
  sink(here::here("logs", str_c("bdu_hist_dataprep.log")),
   append = FALSE,
   split = FALSE
  ) #log output
  Sys.time() %>% print()
}

# DATA

# BDU actual
bdu_actual <- readRDS(here::here("data", "BDU", "bdu_actual_sean.rds")) # bdu_hist.R

# extra rows from the process of anonymizing IDs
bdu_actual %>% setorder(afiliacion_id)
bdu_actual <- bdu_actual[!(
  is.na(giro) & 
  is.na(criterio_encad) & 
  is.na(fecha_cancela) & 
  is.na(clave_cancela) & 
  is.na(desc_cancelacion) & 
  is.na(inst_cancela) & 
  is.na(cp) &
  is.na(poblacion) &
  is.na(cat_credito) &
  is.na(cat_debito) &
  is.na(asig_cat_debito)
)]
bdu_actual[, actual := 1] # for merge

print("names(bdu_actual)")
bdu_actual %>% names() %>% print()

# BDU HISTORICO
if (use_real_data) {
  bdu_hist <- readRDS(here::here("proc", "bdu_hist.rds")) # bdu_hist_read.R
} else {
  bdu_hist <- readRDS(here::here("proc", "bdu_fake.rds")) %>%  # bdu_fake.R
    as.data.table()
}
# Take a look:
bdu_hist %>% print() 
print("names(bdu_hist)")
bdu_hist %>% names() %>% print()

# Keep the altas 
  # Note: if it had no alta I want to count it as existing before
  #  so merge bdu_actual with bdu_hist restricted to altas
bdu_altas <- bdu_hist[movimiento %in% c("AL", "RE", "RA")]
bdu_altas[, alta := 1] # for merge

bdu_t0 <- bdu_actual %>% anti_join(bdu_altas, 
  by = "afiliacion_id") # anti_join takes the ones in bdu_actual NOT IN bdu_altas
bdu_t0 %>% print() # t0 for time 0 (before bdu historico starts)

# So now any observation that didn't merge with bdu_hist existed since 2006
bdu_by_cp_mcc_t0 <- bdu_t0[, .(pos_t0 = .N), by = .(cp, giro)]
bdu_by_cp_mcc_t0 %>% print()
bdu_by_cp_mcc_t0 %>% tab(pos_t0)

# Make cp a character for later merge
#  (note in fake data it already was; in real data it was an integer):
bdu_by_cp_mcc_t0[, cp := str_pad(cp, width = 5, pad = "0")]

bdu_by_cp_mcc_t0 %>% saveRDS(here::here("proc", "bdu_by_cp_mcc_t0.rds"))

# Zip code to locality mapping
cp_loc <- readRDS(here::here("proc", "cp_loc.rds"))

bdu_by_loc_mcc_t0 <- bdu_by_cp_mcc_t0 %>% merge(cp_loc,
  by.x = "cp",
  by.y = "cod_postal",
  all.x = TRUE,
  all.y = FALSE
)

# SAVE
bdu_by_loc_mcc_t0 %>% saveRDS(here::here("proc", "bdu_by_loc_mcc_t0.rds"))


