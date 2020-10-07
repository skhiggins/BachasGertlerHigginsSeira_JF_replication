# GET LOCALITY POPULATION FROM ITER

# PACKAGE
library(readxl)
library(data.table)
library(tidyverse)
library(dtplyr) # Requires old version 0.0.3; code breaks with 1.0.0
  # Install with remotes::install_version("dtplyr", version = "0.0.3", repos = "http://cran.us.r-project.org")
library(magrittr)
library(assertthat)
library(haven)
library(here)

# FUNCTIONS
source(here::here("scripts", "myfunctions.R"))

########################################################################################################
# 2010
# Population from ITER (raw file from INEGI)
iter <- fread(here::here("data", "ITER", "2010", "ITER_NALTXT10.TXT")) %>% 
  lowercase_names() %>% 
  tbl_dt()

# Create localidad string (missing for the rows that are aggregations)
iter[, localidad := ifelse(
  entidad == 0 | mun == 0 | loc == 0, NA, str_c(
    str_pad(entidad, width = 2, pad = "0"),
    str_pad(mun, width = 3, pad = "0"),
    str_pad(loc, width = 4, pad = "0")
  )
)]
iter[, .N] # 198k
iter <- iter[!is.na(localidad)] # those with is.na(localidad) are the aggregates
iter[, .N] # 195k 
iter <- iter[, c("localidad", "tothog", "pobtot", "p18ym_pb")]
assert_that(iter[is.na(pobtot), .N] == 0)

# Convert columns to numeric
to_numeric <- setdiff(names(iter), "localidad")
iter <- iter[, (to_numeric) := lapply(.SD, as.numeric), .SDcols = to_numeric]

iter %>% saveRDS(here::here("proc", "iter2010.rds"))

# Just the urban ones
iter %>% 
  filter(pobtot > 15000) %>% 
  saveRDS(here::here("proc", "iter2010_urban.rds"))
# How many urban?
iter %>% filter(pobtot > 15000) %>% tabcount(localidad) # 630

# Create a version that just lists the urban localities, 
#  to send to INEGI as csv (for data request)
iter_urban_tosend <- iter %>% 
  filter(pobtot > 15000) %>% 
  select(localidad) %>% 
  mutate(
    cve_edo = str_sub(localidad, 1, 2),
    cve_mun = str_sub(localidad, 3, 5),
    cve_loc = str_sub(localidad, 6, 9)
  )
iter_urban_tosend %>% 
  fwrite(here::here("proc", "localidades_urbanas.csv"))

# Also create one at municipality level for municipality level data sets
iter[, ":="(municipio = str_sub(localidad, 1, 5), is_urban = pobtot > 15000)]
iter_mun <- iter[, .(pobtot = sum(pobtot), has_urban = max(is_urban)), by = "municipio"]
iter_mun[, in_iter := 1] # for merge
iter_mun %>% saveRDS(here::here("proc", "iter_mun.rds"))

# Stata version to share with Pierre for CoDi project
iter_mun %>% write_dta(here::here("proc", "iter_mun.dta"))

########################################################################################################
# 2005
#  Note 2005 didn't have column names, whereas 2010 did. So add them manually:
iter05 <- fread(here::here("data", "ITER", "2005", "ITER_NALTXT05.txt")) %>% 
  lowercase_names() %>% 
  tbl_dt()
# Read in names (prepared by RA Nils Lieber)
iter05_names <- read_excel(here::here("data", "ITER", "2005", "fd_iter_2005.xlsx"))
names(iter05) <- iter05_names$Mnemónico
iter05 %<>% lowercase_names()

iter05[, localidad := ifelse(
  entidad == 0 | mun == 0 | loc == 0, NA, str_c(
    str_pad(entidad, width = 2, pad = "0"),
    str_pad(mun, width = 3, pad = "0"),
    str_pad(loc, width = 4, pad = "0")
  )
)]
iter05[, .N] # 194k
iter05 <- iter05[!is.na(localidad)] # those with is.na(localidad) are the aggregates
iter05[, .N] # 192k 

# How many urban?
iter05[, pobtot := p_total] # so it has the same name as in 2010
iter05[pobtot > 15000, .N] # 550

# Remaining cols to numeric
not_numeric <- c("localidad", "entidad", "nom_ent", "nom_mun", "loc", "nom_loc")
to_numeric <- setdiff(names(iter05), not_numeric)
iter05 <- iter05[, (to_numeric) := lapply(.SD, as.numeric), .SDcols = to_numeric]

assert_that(iter05[is.na(pobtot), .N] == 0)

iter05[, pct_illiterate := p_15maan/p_15ymas] # % illiterate (age 15+)
iter05[, pct_not_attending_school := p6a14noa/p_6a14_an]
iter05[, pct_primary_incomplete := (p15ymase + p15ym_ebin)/(p15ymase + p15ym_ebin + p15ym_ebc + p15ymapb)]
iter05[, pct_no_health_ins := p_sinder/pobtot]
assert_that(all(iter05$pro_c_vp != 0, na.rm = TRUE)) # make sure no 0s before taking logs
iter05[, ln_oc_per_room := log(pro_c_vp)] # Note the CONEVAL methodological doc says they use natural log
iter05[, pct_dirt_floor := vph_con_pt/vivparha]
iter05[, pct_no_toilet := (vivparha - vph_excsa)/vivparha] 
iter05[, pct_no_water := vph_noag/vivparha]
iter05[, pct_no_plumbing := vph_nodren/vivparha]
iter05[, pct_no_electricity := (vivparha - vph_enel)/vivparha]
iter05[, pct_no_washer := (vivparha - vph_lava)/vivparha]
iter05[, pct_no_fridge := (vivparha - vph_refr)/vivparha]

# Keep only the needed vars
main_vars <- c("localidad", "pobtot")
pct_vars <- iter05 %>% select_colnames("^pct_")
oc_vars <- c("pro_c_vp", "ln_oc_per_room")
iter05 %<>% select(c(main_vars, pct_vars, oc_vars))

# SAVE
iter05 %>% saveRDS(here::here("proc", "iter2005.rds"))

# Just the urban ones
iter05 %>% 
  filter(pobtot > 15000) %>% 
  saveRDS(here::here("proc", "iter2005_urban.rds"))

