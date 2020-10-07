# PREPARE ELECTIONS DATA FOR EVENT STUDY


# PACKAGES
library(haven)
library(zoo) # for na.locf
library(tidyverse)
library(data.table)
library(dtplyr) # Requires old version 0.0.3; code breaks with 1.0.0
  # Install with remotes::install_version("dtplyr", version = "0.0.3", repos = "http://cran.us.r-project.org")
library(magrittr)
library(assertthat)
library(here)

# FUNCTIONS
source(here::here("scripts", "myfunctions.R"))

# DATA
elections <- readRDS(here::here("proc", "elections_party_by_year.rds"))
iter_mun <- readRDS(here::here("proc", "iter_mun.rds"))
cards_mun <- readRDS(here::here("proc", "cards_mun.rds")) %>% tbl_dt()
cards_mun %<>% select(municipio, contains("switch")) %>% 
  as.data.table()

elections %<>% merge(cards_mun, 
  all.x = TRUE, all.y = FALSE, # left_join
  by = "municipio"
)
elections %<>% merge(iter_mun, 
  all.x = TRUE, all.y = FALSE,
  by = "municipio"
)

# Keep urban only
elections %>% tabcount(municipio) # 1650
elections[has_urban == 1] %>% tabcount(municipio) # 521
elections <- elections[has_urban == 1]

elections[, ":="(
  year_switch = str_sub(bimswitch, 1, 4),  
  bim_switch = str_sub(bimswitch, 5, 5)
)]
elections %>% tab(bim_switch)
elections %>% tab(year_switch)

# Prepare for event study
elections[, year_since_switch := ifelse(
  !is.na(bimswitch), as.numeric(year_) - as.numeric(year_switch), -1) %>% 
  as.factor() %>% relevel(ref = "-1")
]
elections %>% tab(year_since_switch)

# Define treatment (same as in other event study files)
elections[, treat := ifelse(is.na(bimswitch), 0, ifelse(
  (year_switch < 2012) | (year_switch == 2012 & bim_switch < 4), 1, NA))]

# SAVE
elections %>% saveRDS(here::here("proc", "elections_forreg.rds"))
