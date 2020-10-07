# DATA PREP FOR EVENT STUDY OF NUMBER OF BENEFICIARIES

############
# PACKAGES #
############
library(data.table)
library(tidyverse)
library(dtplyr) # Requires old version 0.0.3; code breaks with 1.0.0
  # Install with remotes::install_version("dtplyr", version = "0.0.3", repos = "http://cran.us.r-project.org")
library(magrittr)
library(assertthat)
library(here)

#############
# FUNCTIONS #
#############
source(here::here("scripts", "myfunctions.R"))

# PRELIMINARIES
start_year <- 2007

########
# DATA #
########
cards <- readRDS(here::here("proc", "cards_bybim_urban.rds"))
cards_byyear <- readRDS(here::here("proc", "cards_byyear_urban.rds"))
cards_bim6 <- cards[bim == 6]
  # double checked they are identical for overlapping years, so:
cards_pob <- readRDS(here::here("proc", "cards_pob.rds"))
cards_pob <- cards_pob[, .(localidad, bimswitch, year_switch, bim_switch, debit_cards_instant)]
 
# Check the localities
cards_byyear %>% tabcount(localidad) # 600
cards_byyear %>% tab(year) # 2000-2011
cards_bim6 %>% tabcount(localidad)   # 599
cards_bim6 %>% tab(year) # 2008-2016
cards_byyear <- cards_byyear[year >= start_year] # first year for which we have the full sample of 599 localities
drop <- anti_join(cards_byyear %>% tbl_dt() %>% distinct(localidad), cards_bim6 %>% tbl_dt() %>% distinct(localidad)) %>% 
  as_tibble() %>% 
  .$localidad
  # just 10, i.e. cards_bim6 has strict subset of the ones in cards_byyear
  #  (since I already removed the ones that didn't have Prospera in 2008 from cards_byyear)
# Just to make sure:
assert_that(
  anti_join(cards_bim6 %>% tbl_dt() %>% distinct(localidad), cards_byyear %>% tbl_dt() %>% distinct(localidad)) %>% 
    as_tibble() %>% 
    nrow() == 0
)

# Keep common columns
common_cols <- intersect(names(cards_bim6), names(cards_byyear))
cards_bim6 <- cards_bim6[, common_cols, with = FALSE]
cards_byyear <- cards_byyear[year < 2008, common_cols, with = FALSE] # since other data starts in 2008
cards_combined <- rbindlist(list(cards_byyear, cards_bim6))
cards_combined %>% tabcount(localidad) # 600, so I guess 9 of the extra didn't exist pre-2008?
# Double check:
cards_byyear[year < 2008] %>% tabcount(localidad) # yep, 600

# Merge with bimswitch
cards_combined %<>% merge(cards_pob, by = "localidad", all.x = TRUE, all.y = FALSE)

# Prepare for event study
year_key <- data.table(sort(unique(cards_combined$year)), 
  1:length(unique(cards_combined$year)))
names(year_key) <- c("year", "year_key")

# Periods since switch
cards_combined[, year_switch := as.character(year_switch)]
cards_combined %<>% merge(year_key, by.x = "year_switch", by.y = "year", all.x = TRUE, all.y = FALSE)
cards_combined[, ":="(yearswitch_key = year_key, year_key = NULL)] # rename
cards_combined %<>% merge(year_key, by = "year", all.x = TRUE, all.y = FALSE)
  # don't need to rename this one

cards_combined[, bim := 6] # for all obs
cards_combined[, yearbim := str_c(year, bim)]

# 
min_bim_cards <- cards_combined %$% min(yearbim, na.rm = TRUE)
max_bim_cards <- cards_combined %$% max(yearbim, na.rm = TRUE)
min_bimswitch <- cards_combined %$% min(bimswitch, na.rm = TRUE)
max_bimswitch <- cards_combined %$% max(bimswitch, na.rm = TRUE)

min_bim <- min(min_bim_cards, min_bimswitch)
max_bim <- max(max_bim_cards, max_bimswitch)

min_bim_year <- str_sub(min_bim, 1, 4) %>% as.integer()
min_bim_bim <- str_sub(min_bim, 5, 5) %>% as.integer()
max_bim_year <- str_sub(max_bim, 1, 4) %>% as.integer()
max_bim_bim <- str_sub(max_bim, 5, 5) %>% as.integer()

min_bim_year %>% print() # debugging
max_bim_year %>% print()
min_bim_bim %>% print()
max_bim_bim %>% print()
rows <- (max_bim_year - min_bim_year + 1)*6 
rows %>% print()
year_bim_key <- matrix(nrow = rows, ncol = 2)
r <- 0
for (year in seq(min_bim_year, max_bim_year, by = 1)) {
  for (bim in seq(1, 6, by = 1)) { # starts at 1 even if min_bim_bim > 1
    r <- r + 1
    year_bim_key[r, 1] <- str_c(year %>% as.character(), bim %>% as.character())
    year_bim_key[r, 2] <- r 
  }
}
year_bim_key <- year_bim_key %>% as.data.table()
names(year_bim_key) <- c("year_bim", "bim_key")
year_bim_key[, bim_key := as.integer(bim_key)]
year_bim_key %>% print()

cards_combined %<>% merge(year_bim_key, by.x = "bimswitch", by.y = "year_bim", 
  all.x = TRUE, all.y = FALSE  
)
cards_combined[, ":="(bimswitch_key = bim_key, bim_key = NULL)]
cards_combined %<>% merge(year_bim_key, by.x = "yearbim", by.y = "year_bim",
  all.x = TRUE, all.y = FALSE  
)

# Years since switch
cards_combined[, year_since_switch := 
  ifelse(!is.na(bimswitch), year_key - yearswitch_key, -1) %>% 
  # since -1 is omitted period, put control as -1 so that they
  # have 0 for all the interaction dummies included
  as.factor() %>% relevel(ref = "-1")
  # as.factor for the regression dummies; relevel to omit k=-1
]
cards_combined %>% tab(year_since_switch)

# Bimesters since switch
cards_combined[, bim_since_switch := 
  ifelse(!is.na(bimswitch), bim_key - bimswitch_key, -1) %>% 
  # since -1 is omitted period, put control as -1 so that they
  # have 0 for all the interaction dummies included
  as.factor() %>% relevel(ref = "-1")
  # as.factor for the regression dummies; relevel to omit k=-1
]
cards_combined %>% tab(bim_since_switch)
  # could bounce around a lot due to missing obs

# Treatment var
cards_combined[, treat := !is.na(bimswitch)]
cards_combined[, .(treat = max(treat)), by = "localidad"] %>% tab(treat) %>% print()
  # 299 control, 259 treated, 41 NA (treated after first half 2012)

cards_combined %<>% winsorize("fams", newvar = "fams_w", w = 5, highonly = TRUE)

# Rename vars as they are in function call
cards_combined[, year_bim := yearbim] # just to use same function as before
cards_combined[, bim_since_switch := year_since_switch]
cards_combined[, ln_fams := log(fams)]
cards_combined[, ln_fams_w := log(fams_w)]

########
# SAVE #
########
cards_combined %>% saveRDS(here::here("proc", "prospera_forreg.rds"))


