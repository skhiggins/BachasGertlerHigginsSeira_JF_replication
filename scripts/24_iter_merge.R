# Prepare locality data for discrete time hazard

# PACKAGES
library(haven)
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
iter05 <- readRDS(here::here("proc", "iter2005.rds"))
iter05 %<>% rename(pobtot_2005 = pobtot) 

# Also read in ITER 2010 to see which localities became urban between 2005 and 2010
iter10 <- readRDS(here::here("proc", "iter2010.rds"))
iter10 %<>% rename(pobtot_2010 = pobtot) %>% 
  select(localidad, pobtot_2010)

# Assert that pobtot is not missing for any localities
assert_that(all(!is.na(iter05$pobtot_2005)))
assert_that(all(!is.na(iter10$pobtot_2010)))
  # that way I can check for missings to see which didn't merge

iter <- merge(iter05, iter10, by = "localidad", all = TRUE)
iter[, ln_pobtot_2005 := log(pobtot_2005)]
iter[, ln_pobtot_2010 := log(pobtot_2010)]

iter[pobtot_2005 > 15000 & is.na(pobtot_2010)] # just 1 urban locality that stopped existing
iter[pobtot_2010 > 15000 & is.na(pobtot_2005)] # 9 new urban localities

iter[pobtot_2005 < 15000 & pobtot_2010 > 15000, .N] # 78, so they are just new urban localities

# # Merge with bimswitch to see what's going on with those 78
# cards_pob <- readRDS(here::here("proc", "cards_pob.rds"))
# cards_pob <- cards_pob[, c("tothog", "pobtot", "p18ym_pb") := NULL] # drop extra vars
# 
# iter %<>% merge(cards_pob, by = "localidad", all.x = TRUE, all.y = FALSE)
# 
# iter[pobtot_2005 <= 15000 & pobtot_2010 > 15000] %>%
#   .[!is.na(bimswitch) & bimswitch < 20124] %>% 
#   tab(bimswitch)
#   # just 9 localities so it shouldn't matter much whether I use 2005 or 2010 population
#   # keep both just to make sure robust

# Urban (keep if >15000 population in either Census wave so that I can check robustness)
iter[pobtot_2005 > 15000 | pobtot_2010 > 15000, .N] # 637
iter[pobtot_2005 > 15000, .N] # 550
iter[pobtot_2010 > 15000, .N] # 630

# # How many urban localities in rollout?
# iter[pobtot_2005 > 15000 & !is.na(bimswitch) & bimswitch < 20124] # 253
# iter[pobtot_2010 > 15000 & !is.na(bimswitch) & bimswitch < 20124] # 259

# Merge in number of Bansefi branches
n_bansefi <- readRDS(here::here("proc", "n_bansefi.rds")) # branches_localities.R
iter %<>% merge(n_bansefi, all.x = TRUE)
iter[, n_bansefi := na_to_0(n_bansefi)]
iter[, n_bansefi_percap_2005 := n_bansefi/pobtot_2005]
iter[, n_bansefi_percap_2010 := n_bansefi/pobtot_2010]

##########################################################################################################
# SAVE
iter %>% saveRDS(here::here("proc", "iter.rds"))
iter[pobtot_2005 > 15000 | pobtot_2010 > 15000] %>% saveRDS(here::here("proc", "iter_urban.rds"))

# Save as .dta 
iter %>% write_dta(here::here("proc", "iter.dta"))
iter[pobtot_2005 > 15000 | pobtot_2010 > 15000] %>% write_dta(here::here("proc", "iter_urban.dta"))


