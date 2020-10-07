# Create crosswalk between branches and localities
#  13jun2019

library(sf)
library(tidyverse)
library(data.table)
library(dtplyr) # Requires old version 0.0.3; code breaks with 1.0.0
  # Install with remotes::install_version("dtplyr", version = "0.0.3", repos = "http://cran.us.r-project.org")
library(magrittr)
library(haven)
library(assertthat)
library(here)

source(here::here("scripts", "myfunctions.R"))
  # includes tabulator

branch_coord <- read_sf(
  here::here("data", "shapefiles", "bansefi_geocoordinates"), 
  "suc_bansefi_2008ccl"
) %>% st_transform(4326) %>%  # longlat
  lowercase_names()

# Create just a mapping between 
branch_coord_nogeom <- branch_coord
st_geometry(branch_coord_nogeom) <- NULL
branch_coord_nogeom %<>% tbl_dt()

# Make sure no duplicates
branch_coord_nogeom[, .N]
branch_coord_nogeom %>% tabcount(sucursales)
# one duplicate
branch_coord_nogeom[, duplicates := .N, by = "sucursales"]
branch_coord_nogeom[duplicates == 2] 

# Manually fix the one with a duplicate
#  (using information from full directory bansefi.xlsx)
#  which says the one in TLACHICHUCA is 570 and the one in 
#  TOTUTLA is 585. First check no 585 in the data set
assert_that(branch_coord_nogeom[sucursales == 585, .N] == 0)
assert_that(branch_coord_nogeom[nommun == "TOTUTLA", .N] == 1)
branch_coord_nogeom[, 
  sucursales := ifelse(nommun == "TOTUTLA", 585, sucursales)  
]

# Make sure it worked
branch_coord_nogeom[, duplicates := .N, by = "sucursales"]
assert_that(all(branch_coord_nogeom$duplicates == 1))

# Rename every var with branch prefix
names(branch_coord_nogeom) %<>% map_chr(function(x) {
  str_c("branch_", x)
})
branch_coord_nogeom %<>% rename(sucadm = branch_sucursales) # for merge

# Just the branch number and locality for merging
branch_loc <- branch_coord_nogeom %>% select(sucadm, branch_clave_loc)

# Number of Bansefi branches per locality
n_bansefi <- branch_coord %>% 
  mutate(localidad = str_pad(clave_loc, width = 9, pad = "0")) %>% 
  group_by(localidad) %>% 
  summarize(n_bansefi = n())
st_geometry(n_bansefi) <- NULL # convert from sf object to tbl_df

# SAVE
branch_coord %>% saveRDS(here::here("proc", "branches.rds")) # entire sf object
branch_coord_nogeom %>% saveRDS(here::here("proc", "branches_nogeom.rds"))
branch_loc %>% saveRDS(here::here("proc", "branch_loc.rds"))
branch_loc %>% write_dta(here::here("proc", "branch_loc.dta"))
n_bansefi %>% saveRDS(here::here("proc", "n_bansefi.rds"))
