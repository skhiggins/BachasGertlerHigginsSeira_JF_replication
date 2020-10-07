# CREATE DATA SET WITH ROLLOUT OF PROSPERA DEBIT CARDS
#  Sean Higgins

# PACKAGES
library(data.table)
library(tidyverse)
library(lubridate) # for manipulating dates
library(assertthat)
library(magrittr)
library(here)

# FUNCTIONS
source(here::here("scripts", "myfunctions.R"))

# Prospera debit cards
cards <- readRDS(here::here("proc", "fams_prosp_combined.rds")) %>% 
  as.data.table() # previously saved as a tibble
cards %>% setorder(localidad, year, bim)

# Convert bim and year to numeric and
#  add the 1-bimester delay between when Prospera records the cards as being distributed
#  and when they are actually distributed according to Bansefi data
cards[, ':=' (
  year = ifelse(as.numeric(bim) > 5, as.numeric(year) + 1, as.numeric(year)),
  bim  = ifelse(as.numeric(bim) > 5, as.numeric(bim) + 1 - 6, as.numeric(bim) + 1)
)]

# Look into switching
cards[, max_cards := max(debit_cards), by = "localidad"]
cards[, .N]
cards[max_cards > 0, .N, by = "localidad"]

# How many of the localities were part of Prospera when data start?
cards[, .N, by = "localidad"][, .N] # 129k localities
cards[year == 2008 & bim == 2, .N, by = "localidad"][, .N] # 92k, not bad
  # need to drop other localities since in those localities getting a card would also
  #  increase the people's incomes (getting Prospera at the same time)

# Restrict to balanced panel of localities that were part of Prospera the whole time 
#  (otherwise effect could be driven by new beneficiaries coming in)
cards %>% tab(year, bim)
min_year <- cards %$% min(year)
min_bim_of_year <- cards[year == min_year] %$% min(bim)
cards[, is_start := ifelse(year == min_year & bim == min_bim_of_year & fams > 0, 1, 0)]
max_year <- cards %$% max(year)
max_bim_of_year <- cards[year == max_year] %$% max(bim)
cards[, is_end := ifelse(year==max_year & bim == max_bim_of_year & fams > 0, 1, 0)]
cards[, since_start := max(is_start), by = "localidad"]
cards[, until_end := max(is_end), by = "localidad"]
cards[, yearbim := str_c(year, bim)]

cards[since_start == 1 & until_end == 1, .N, by = "localidad"][, .N]
  # 86k localities in balanced sample
cards_bal <- cards[since_start == 1 & until_end == 1]
cards_bal %>% setorder(localidad, year, bim)
cards_bal %>% tab(year, bim)

# totally balanced sample? (none missing in middle)
#  explore these to see whether to drop or interpolate in the middle
cards_bal[, N_bim := .N, by = "localidad"]
cards_bal %>% tab(N_bim) # note there are 43 periods but some have more obs
  # if more than one payment method during a period
cards_bal[N_bim >= 43, .N, by = "localidad"][, .N]/
  cards_bal[, .N, by = "localidad"][, .N]
  # 98% have balanced panel

# explore those who don't
# cards_bal[N_bim < 43] %>% View() # they have very small # of beneficiary families
cards_bal[N_bim < 43] %$% summary(fams)
  # 75th percentile is 3 beneficiary families, max is 402
  # So no issue with dropping these

cards_bal <- cards_bal[N_bim >= 43]

# How many have families receiving benefits by card?
cards_bal[, .N, by = "localidad"][, .N]
cards_bal[max_cards > 0, .N, by = "localidad"][, .N] # just 2137 localities

# SAVE 
cards_bal %>% saveRDS(here::here("proc", "fams_prosp_bal.rds"))
