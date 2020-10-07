# ADOPTION OF POS TERMINALS: COLLAPSE TO MONTH

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
# CONTROL CENTER
tosink <- 1

# LOG
proj <- "bdu_cp_month_dataprep"
if (tosink) {
  Sys.time() %>% print()
  sink(
    here::here("logs", str_c(proj, time_stamp(), ".log")),
    append = FALSE,
    split = TRUE
  )
} 

# DATA
bdu_altas_by_cp_mcc_month <- readRDS(here::here("proc", "bdu_altas_by_cp_mcc_month.rds"))

bdu_altas_by_cp_mcc_month[, year_month := str_c(year, str_pad(month, width = 2, pad = "0"))]

# Note the zip code if <5 digits has spaces; want it to have leading 0s
bdu_altas_by_cp_mcc_month[, cp := str_pad(cp, width = 5, pad = "0")]

# RESTRICT TO URBAN ZIP CODES BEFORE THE CROSS JOIN 
#  to make it a manageable problem
# Merge in CP-mun mapping and ITER so I know which are in urban localities
cp_mun <- readRDS(here::here("proc", "cp_mun.rds")) %>% 
  rename(in_cp = count) # for some reason it also had count
iter_mun <- readRDS(here::here("proc", "iter_mun.rds"))

cp_mun %<>% merge(iter_mun, by = "municipio", all.x = TRUE)
cp_mun %>% tab(in_iter) # nearly all 1

bdu_altas_by_cp_mcc_month %<>% tbl_dt() %>% 
  left_join(cp_mun, by = "cp")
bdu_altas_by_cp_mcc_month %>% tab(in_cp)

print("Number of CP that didn't merge")
bdu_altas_by_cp_mcc_month %>% filter(is.na(municipio)) %>% tabcount(cp) %>% print()
print("total CP")
bdu_altas_by_cp_mcc_month %>% tabcount(cp) %>% print()

# Restrict
bdu_altas_by_cp_mcc_month %>% tab(has_urban)
bdu_altas_by_cp_mcc_month <- bdu_altas_by_cp_mcc_month[has_urban==1]
bdu_altas_by_cp_mcc_month %>% tab(has_urban)

# DO THE CROSS JOIN HERE
bdu_altas_by_cp_mcc_month %>% setkey(cp, giro, year_month)
print("before cross_join")
bdu_altas_by_cp_mcc_month %>% print() 
n_loc <- bdu_altas_by_cp_mcc_month %>% tabcount(cp)
n_giro <- bdu_altas_by_cp_mcc_month %>% tabcount(giro)
n_bim <- bdu_altas_by_cp_mcc_month %>% tabcount(year_month)
cat("n_loc:", n_loc)
cat("n_giro:", n_giro)
cat("n_bim:", n_bim)
cat("cross_join", n_loc*n_giro*n_bim)

bdu_altas_by_cp_mcc_month <- bdu_altas_by_cp_mcc_month[CJ(cp, giro, year_month, unique = TRUE)]
# Take a look
print("after cross-join")
bdu_altas_by_cp_mcc_month %>% print()
print("!is.na(new_pos)")
bdu_altas_by_cp_mcc_month[!is.na(new_pos)] %>% print()
# Note pos_t0 might be NA in first period when there was no action in that
#  period in BDU historico
bdu_altas_by_cp_mcc_month[, pos_t0 := max(pos_t0, na.rm = TRUE), 
  by = .(cp, giro)
]
# Note the above makes it -Inf if all NA, so
bdu_altas_by_cp_mcc_month[, ":="(
  new_pos = na_to_0(new_pos), 
  pos_t0 = inf_to_0(pos_t0)
)]
bdu_altas_by_cp_mcc_month[, ":="(
  year = str_sub(year_month, 1, 4),
  month = str_sub(year_month, 5, 6)
)]

print("N cp")
bdu_altas_by_cp_mcc_month %>% tabcount(cp) %>% print()

bdu_cp_month <- bdu_altas_by_cp_mcc_month
bdu_cp_month %>% setorder(cp, giro, year, month)
bdu_cp_month[, cum_new_pos := cumsum(new_pos), by = list(cp, giro)]
bdu_cp_month[, cum_new_pos := cum_new_pos + pos_t0]

# SAVE
bdu_cp_month %>% saveRDS(here::here("proc", "bdu_cp_month_urban.rds"))

# CLOSE LOG 
warnings() %>% print()
Sys.time() %>% print()
if (tosink) sink()


