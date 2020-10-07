# BALANCED PANEL OF LOCALITIES THAT RECEIVED DEBIT CARDS
#  Sean Higgins

# PACKAGES
library(data.table)
library(tidyverse)
library(plm) # for pdata.frame lags
library(haven)
library(here)

# FUNCTIONS
source(here::here("scripts", "myfunctions.R"))

# Prospera debit cards
cards <- readRDS(here::here("proc", "fams_prosp_bal.rds")) # cards_dataprep.R

# Combine those with multiple obs per i,t
cards[, N_loc_bim := .N, by = .(localidad, year, bim)]
cards %>% tab(N_loc_bim) # 2% have 2
cards[N_loc_bim == 2] %>% tab(descripcio)
cards <- cards[, .(
  debit_cards = sum(debit_cards),
  fams = sum(fams), 
  year = max(year), # constant
  bim = max(bim) # constant
), by = .(localidad, yearbim)][order(localidad, yearbim)]
# Create a key for yearbim so that e.g. 20091 won't be missing since it's not 1 after
#  20086
ordered_yearbim <- cards[, .N, by = yearbim]$yearbim %>% sort()
year_bim_key <- data.frame(ordered_yearbim, 1:length(ordered_yearbim))
names(year_bim_key) <- c("yearbim", "yearbim_key")

cards[, .N]

# Generate first period with cards
cards_panel <- cards %>% 
  merge(year_bim_key, all.x = TRUE, all.y = FALSE, by = "yearbim") %>% 
  pdata.frame(index = c("localidad", "yearbim_key"))
cards_panel$lag_cards = lag(cards_panel$debit_cards)
cards_panel$switch <- (cards_panel$debit_cards > 0 & cards_panel$lag_cards == 0)

cards$switch = cards_panel$switch
cards[, bimswitch_ := ifelse(switch, yearbim, NA_real_)]
# do any have multiple bimswitch? (for example, switched away from cards then back to cards)
cards[, N_switch := sum(switch), by = .(localidad, year, bim)]
cards %>% tab(N_switch) # none have more than one, meaning no loc switched away from cards then back to cards
cards[, bimswitch := min(bimswitch_, na.rm = TRUE), by = .(localidad)]
cards[, bimswitch_ := NULL] # no longer needed
cards[, ':=' (year_switch = as.integer(str_sub(bimswitch, 1, 4)), 
  bim_switch = as.integer(str_sub(bimswitch, 5, 5))
)]

cards %>% tab(bimswitch)
cards %>% tab(year_switch)
# cards <- cards[year_switch < 2015]
cards[, mo_since_switch := (2014 - year_switch)*12 + (6 - bim_switch)*2]

# check distribution of months since switch
cards %>% tab(mo_since_switch) # (by locality)
cards %>% ggplot() +
  geom_histogram(aes(x = mo_since_switch))
# weighted by pop
cards %>% ggplot() +
  geom_histogram(aes(x = mo_since_switch, weight = fams))  
# this is analogous to the adoption over time graph I show

# Number of cards at bimester of switch
cards[, debit_cards_instant_ := ifelse(switch == 1, debit_cards, 0)]
cards[, debit_cards_instant := max(debit_cards_instant_), by = .(localidad)]
cards[, debit_cards_instant_ := NULL]

# Just need to keep last period
cards_last <- cards[yearbim == max(yearbim)]
cards_last[, ':='(yearbim = NULL, year = NULL, bim = NULL, switch = NULL)]

# Merge in population from ITER
iter <- readRDS(here::here("proc", "iter2010.rds"))

cards_pob <- merge(cards_last, iter, by = "localidad", all.x = TRUE, all.y = FALSE)

cards_pob[, percent_treat := fams/tothog]
cards_pob %>% quantiles(percent_treat, na.rm = TRUE)
cards_pob %>% quantiles(percent_treat, probs = seq(0.9, 1, 0.01), na.rm = TRUE)
# cards_pob[percent_treat > 1] %>% View() # all in small localities

cards_pob %>% quantiles(pobtot, na.rm = TRUE)
# a lot of small ones; doesn't matter since analysis restricted to urban

# SAVE
cards_pob %>% saveRDS(here::here("proc", "cards_pob.rds"))

# Create a version at municipality level for municipality-level data sets
cards_pob <- cards_pob[!is.na(bimswitch)]
cards_pob[, municipio := str_sub(localidad, 1, 5)]
cards_mun <- cards_pob[, .(
  debit_cards = sum(debit_cards, na.rm = TRUE),
  debit_cards_instant = sum(debit_cards_instant, na.rm = TRUE),
  fams = sum(fams, na.rm = TRUE), 
  bimswitch = min(bimswitch), # potentially problematic in mun with multiple loc, 
  # but since restricting to urban should be OK
  tothog = sum(tothog, na.rm = TRUE),
  pobtot = sum(pobtot, na.rm = TRUE)
), by = "municipio"]
cards_mun[, .N] # 267
cards_mun[, in_cards := 1]

# SAVE
cards_mun %>% saveRDS(here::here("proc", "cards_mun.rds"))
cards_mun %>% write_dta(here::here("proc", "cards_mun.dta"))


