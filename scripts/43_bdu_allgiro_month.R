# Create data set with all POS (across all giros) per month 
#  Sean Higgins

# PACKAGES
library(tidyverse)
library(data.table)
library(dtplyr) # Requires old version 0.0.3; code breaks with 1.0.0
  # Install with remotes::install_version("dtplyr", version = "0.0.3", repos = "http://cran.us.r-project.org")
library(magrittr)
library(here)

# FUNCTIONS
source(here::here("scripts", "myfunctions.R"))

# Create long data frame (specific to the structure of data in this script)
longify_ <- function(dt, at = c("localidad", "ent")) { 
  # longify_ differs from longify in that there's no giro field here
  month_cols_select <- dt %>% select_colnames("[0-9]{2}")
  new_dt <- dt %>% 
    melt(id.vars = at, measure.vars = month_cols_select, 
    variable.name = "yy_mm",
    value.name = "pos"
  )
  new_dt[, c("yy", "month") := tstrsplit(yy_mm, split = "_")]  
  new_dt[, year := str_c("20", yy)]
  new_dt
}

# DATA
bdu <- read_csv(here::here("proc", "bdu_cp_month_means_new.csv"), 
  col_types = cols(.default = col_integer(), cp = col_character())  
) %>% tbl_dt() # bdu_cp_month_read.py

# Merge with municipios
cp_loc <- readRDS(here::here("proc", "cp_loc.rds")) # denue_codigos_postales.R
cp_loc %<>% 
  rename(cp = cod_postal) %>% 
  select(-percent) %>% 
  mutate(
    in_cp = 1, 
    ent = str_sub(localidad, 1, 2)
  )

bdu %<>% left_join(cp_loc, by = "cp")
bdu %>% tab(in_cp) # 90% match
bdu[is.na(in_cp)] # very few POS in these zips anyway

# Aggregate to locality level
month_cols <- bdu %>% select_colnames("[0-9]{2}")
bdu_loc <- bdu[, lapply(.SD, sum), .SDcols = month_cols, 
  by = c("localidad", "ent")]
bdu_loc <- bdu_loc[!is.na(localidad)]

month_cols_select <- bdu_loc %>% select_colnames("[0-9]{2}")
bdu_long <- bdu_loc %>% 
  melt(id.vars = c("localidad", "ent"), measure.vars = month_cols_select, 
    variable.name = "yy_mm",
    value.name = "pos"
  )
bdu_long[, c("yy", "month") := tstrsplit(yy_mm, split = "_")]  
bdu_long[, year := str_c("20", yy)]
bdu_long

bdu_long <- longify_(bdu_loc)
bdu_cp_long <- longify_(bdu, at = c("cp", "localidad"))

bdu_long %>% saveRDS(here::here("proc", "bdu_loc_long_allgiro.rds"))
bdu_cp_long %>% saveRDS(here::here("proc", "bdu_cp_long_allgiro.rds"))
