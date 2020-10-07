# PREPARE CARDS DATA BY BIMESETER

############
# PACKAGES #
############
library(data.table)
library(tidyverse)
library(magrittr)
library(assertthat)
library(here)

#############
# FUNCTIONS #
#############
source(here::here("scripts", "myfunctions.R"))

########
# DATA #
########
cards <- readRDS(here::here("proc","fams_prosp_bal.rds")) # cards_graph.R # data.table
cards_pob <- readRDS(here::here("proc","cards_pob.rds")) # cards_panel.R # data.table

cards_pob[, treat := ifelse(is.na(bimswitch), 0, ifelse(
  (year_switch < 2012) | (year_switch == 2012 & bim_switch < 4), 1, NA))]

cards_pob[pobtot > 15000 & treat==1] %>% quantiles(debit_cards) # median = 1726
cards_pob[pobtot > 15000 & treat==1] %>% quantiles(debit_cards_instant, na.rm = TRUE) # median = 1327
  # so about 77% of the eventual (by end 2015) cardholders receive cards at time of shock
  #  (this is because # beneficiaries increases over time, not because not all existing
  #   beneficiaries get the shock)
  # note the na.rm needed but only 8 have missing debit_cards_instant...not sure why

  # to compare to hh's with debit cards in urban areas according to MxFLS
cards_pob[pobtot > 15000 & treat==1, mean(debit_cards_instant, na.rm = TRUE)] # 2405
cards_pob[pobtot > 15000 & treat==1, sum(debit_cards)] # 807k
cards_pob[pobtot > 15000 & treat==1, sum(debit_cards_instant, na.rm = TRUE)] # 587k

cards_pob %>% tab(bimswitch)

# Note some multiple obs within loc x yearbim, 
#  in the cases where there were two payment methods
cards_collapsed <- cards[, lapply(.SD, sum), .SDcols = c("fams", "debit_cards"), 
  by = .(localidad, year, bim, yearbim)]
# Make sure it worked
cards_collapsed[, N_perbim := .N, by = .(localidad, year, bim)]
assert_that(all(cards_collapsed$N_perbim == 1))
cards_collapsed[, N_perbim := NULL] # don't need it anymore

# Merge cards_pob with cards
cards_pob[pobtot > 15000] %>% quantiles(percent_treat)
  # median: 10% of urban households receive Oportunidades
a <- cards_pob[pobtot > 15000, lapply(.SD, sum), .SDcols = c("fams", "tothog")]
a %>% as_tibble() # for nicer printing
a[[1]]/a[[2]] # in total, 8% of urban households receive Oportunidades
cards_pob[pobtot > 15000] %>% quantiles(fams)
cards_pob[pobtot > 15000] %>% quantiles(tothog)
cards_pob <- cards_pob[, c("localidad", "bimswitch", "year_switch", "bim_switch", 
  "tothog", "pobtot", "p18ym_pb", "debit_cards_instant")]
  # remove cols that are in both data sets

# median # households in urban loc = 7717.5 acc ITER, 8301 acc. MxFLS
cards_collapsed %>% names()
cards_collapsed %<>% merge(cards_pob, by = "localidad", all.x = TRUE, all.y = FALSE)
# Note this data set still has multiple 

cards_collapsed %>% tabcount(localidad) # 84667, these are localities with Prospera since 2008
cards_collapsed %>% saveRDS(here::here("proc", "cards_bybim.rds"))

cards_urban <- cards_collapsed[pobtot > 15000]
cards_urban %>% tabcount(localidad) # 599
cards_urban %>% saveRDS(here::here("proc", "cards_bybim_urban.rds"))

