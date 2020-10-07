# COLLAPSE DENUE BY POSTAL CODE AND LOCALITY TO HAVE A MAPPING BETWEEN THE TWO
#  Sean Higgins

# PACKAGES
library(tidyverse)
library(data.table)
library(dtplyr) # Requires old version 0.0.3; code breaks with 1.0.0
  # Install with remotes::install_version("dtplyr", version = "0.0.3", repos = "http://cran.us.r-project.org")
library(here)

# FUNCTIONS
source(here::here("scripts", "myfunctions.R"))

# DATA
denue <- readRDS(here::here("proc", "denue.rds"))

# Create full localidad string
denue %>% map(typeof) # check column names and types
denue %>% select(starts_with("cve"))
denue[, localidad := str_c(cve_ent, cve_mun, cve_loc)] # already strings with 0s
denue[, loc_ageb := str_c(localidad, ageb)]

# Fix postal code length
denue[, cod_postal := str_pad(cod_postal, width = 5, pad = "0")]

denue %>% tab(localidad) # 18k total
denue %>% tab(cod_postal) # 22k total, 1% with NA

# If hungry, run next line of code to find tacos:
denue[str_detect(nom_estab, "TACO")]

bus_by_cp_loc <- denue[, list(businesses = .N), by = c("cod_postal", "localidad")]
bus_by_cp_loc[order(-businesses)]

bus_by_cp_ageb <- denue[, list(businesses = .N), by = c("cod_postal", "loc_ageb")]
bus_by_cp_ageb[order(-businesses)]

bus_by_loc <- denue[, list(businesses = .N), by = c("localidad")]
saveRDS(bus_by_loc, here::here("proc","bus_by_loc.rds"))

bus_by_ageb <- denue[, list(businesses = .N), by = c("loc_ageb")]
saveRDS(bus_by_ageb, here::here("proc","bus_by_ageb.rds"))

bus_by_cp <- denue[, list(businesses = .N), by = c("cod_postal")]
saveRDS(bus_by_cp, here::here("proc","bus_by_cp.rds"))

# check for one CP
bus_by_cp_loc[cod_postal=="97000"]
  # result: almost all in the same locality

test_cp <- bus_by_cp_ageb[cod_postal=="97000"][, prop_bus := businesses/sum(businesses)][order(-businesses)]
test_cp %>% print()
  # result: spread across 93 AGEBs
  #  about 30% in the same AGEB

bus_by_cp_loc[, percent := 100*businesses/sum(businesses), by="cod_postal"]

bus_by_cp_loc[, biggest := max(percent), by = "cod_postal"]
bus_by_cp_loc[order(cod_postal)]

cp_loc <- bus_by_cp_loc[!is.na(cod_postal)][order(cod_postal, businesses, decreasing = TRUE)] %>% distinct(cod_postal, .keep_all = TRUE)
cp_loc[, quantile(percent, probs = seq(0, 1, .05))]

cp_loc[, .N]

# Explore cases where mapping less clear-cut
#  bus_by_cp_loc[biggest < 75 & !is.na(cod_postal)][order(cod_postal)] %>% View()

# Note: for localities, they are bigger than zip codes so I did cod_postal --> localidad
#  But for AGEB, the AGEB are smaller so do AGEB --> zip code
bus_by_cp_ageb[, percent := 100*businesses/sum(businesses), by = "loc_ageb"]
bus_by_cp_ageb[, biggest := max(percent), by = "loc_ageb"]
bus_by_cp_ageb[order(cod_postal)]

bus_by_cp_ageb[is.na(cod_postal), .N] # 14k...these are businesses not listed in DENUE
bus_by_cp_ageb[is.na(loc_ageb), .N] # just 5
ageb_cp <- bus_by_cp_ageb[!is.na(cod_postal) & !is.na(cod_postal)][order(loc_ageb, businesses, decreasing = TRUE)] %>% distinct(loc_ageb, .keep_all = TRUE)
ageb_cp %>% quantiles(percent) # 10th percentile is 56%, 30th percentile 90% -- seems pretty good

ageb_cp[, .N] # 64k

# SAVE
cp_loc %>% saveRDS(here::here("proc", "cp_loc.rds"))
ageb_cp %>% saveRDS(here::here("proc", "ageb_cp.rds"))

# Also create a data set by rama by zip code
denue[, rama := str_sub(codigo_act, 1, 4)]
bus_by_cp_rama <- denue[, list(businesses = .N), by = c("cod_postal", "rama")]
bus_by_cp_rama %>% saveRDS(here::here("proc", "bus_by_cp_rama.rds"))
