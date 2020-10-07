# READ IN AND CLEAN ELECTIONS DATA
#  Goals: 
#  1) Create data set with a dummy for whether mayor is PAN party, 
#      each year. (Note term begins in the year after election)

# PACKAGES
library(haven)
library(zoo) # for na.locf
library(tidyverse)
library(data.table)
  # replication requires 
  # remotes::install_version("data.table", version = "1.12.0", repos = "http://cran.us.r-project.org")
library(magrittr)
library(assertthat)
library(here)

# FUNCTIONS
source(here::here("scripts", "myfunctions.R"))

# DATA
elections <- read_dta(here::here("data", "INE", "elecciones_long.dta")) %>% 
  as.data.table()
  # raw data hand-coded by Enrique's RA

# Take a look
elections

# Date variables
elections[, c("year_", "month_", "day_") := tstrsplit(fecha, "-")]

# See what years, months, days of month elections take place on
elections %>% tab(year_)
elections %>% tab(month_)
elections %>% tab(day_)

# need to select row with most votes within id_entmun by time
elections[, municipio := str_pad(id_entmun, width = 5, pad = "0")]
elections[, "municipio"] # take a look

elections[, vote_rank := frank(-voto), by = c("municipio", "fecha")]
  # -voto so that most votes gets rank 1
  # data.table::frank() much faster than rank()

# Keep winner of each
winners <- elections[vote_rank==1]
winners %>% nrow() # 7215

winners[, pan_won := str_detect(partido, "PAN")]
winners %>% tab(pan_won) # won in 27%
winners[pan_won == 1] %>% tab(partido) # double check

party_by_year <- winners[, CJ(municipio, year_, unique = TRUE)]
names(party_by_year) <- c("municipio", "year_")
party_by_year %<>% merge(winners, 
  all.x = TRUE, all.y = FALSE, # left_join
  by = c("municipio", "year_")
)
party_by_year %<>% .[order(municipio, year_)]
party_by_year[, election_occurred := !is.na(partido)]
nalocf_cols <- c("partido", "pan_won")
party_by_year[, c("partido", "pan_won") := lapply(.SD, na.locf), 
  .SDcols = c("partido", "pan_won"), by = c("municipio")
]

# Replace the year of the election with previous result
#  since elected official takes office the following year
party_by_year[, partido := ifelse(election_occurred == 1, NA, partido)]
party_by_year[, partido := na.locf(partido, na.rm = FALSE), 
  by = c("municipio")  
]

party_by_year[, partido_pan := str_detect(partido, "PAN")]
party_by_year[, partido_pri := str_detect(partido, "PRI")]
party_by_year[, partido_same := ifelse(year < 2013, partido_pan, partido_pri)]
party_by_year %>% tab(partido_pri)

# Version with vote shares
elections[, total_votes := sum(voto), by = c("municipio", "year_")]
vote_shares_pan <- elections[str_sub(partido, 1, 3) == "PAN"][, 
  vote_share_pan := voto/total_votes][,
  c("municipio", "year_", "vote_share_pan") # select cols  
]
vote_shares_pri <- elections[str_sub(partido, 1, 3) == "PRI"][, 
  vote_share_pri := voto/total_votes][,
  c("municipio", "year_", "vote_share_pri") # select cols  
]
vote_shares_other <- elections[!(str_sub(partido, 1, 3) %in% c("PRI", "PAN"))][, 
  vote_share_other := voto/total_votes][,
  c("municipio", "year_", "vote_share_other") # select cols  
]

# vote_shares_other has more than one due to multiple other parties
#  or multiple alliances even with PAN and PRI
vote_shares_pan <- vote_shares_pan[, lapply(.SD, sum), by = c("municipio", "year_")]
vote_shares_pri <- vote_shares_pri[, lapply(.SD, sum), by = c("municipio", "year_")]
vote_shares_other <- vote_shares_other[, lapply(.SD, sum), by = c("municipio", "year_")]

vote_shares <- vote_shares_pan %>% 
  merge(
    vote_shares_pri, 
    all.x = TRUE, all.y = TRUE, # full_join
    by = c("municipio", "year_")
  ) %>% 
  merge(
    vote_shares_other, 
    all.x = TRUE, all.y = TRUE, # full_join
    by = c("municipio", "year_")   
  )
vote_cols <- vote_shares %>% select_colnames("vote_share")
vote_shares[, (vote_cols) := lapply(.SD, na_to_0), .SDcols = vote_cols]

# Wide version for discrete time hazard
partido_vars <- party_by_year %>% select_colnames("partido")
party_wide <- party_by_year %>% dcast(municipio ~ year_, 
  value.var = partido_vars
)

# SAVE
party_by_year %>% saveRDS(here::here("proc", "elections_party_by_year.rds"))

vote_shares %>% saveRDS(here::here("proc", "elections_vote_shares.rds"))

party_wide %>% saveRDS(here::here("proc", "elections_party_wide.rds"))
party_wide %>% write_dta(here::here("proc", "elections_party_wide.dta"))

