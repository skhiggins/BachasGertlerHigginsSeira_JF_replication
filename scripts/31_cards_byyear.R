# PREPARE CARDS DATA BY YEAR

############
# PACKAGES #
############
library(foreign)
library(tidyverse)
library(data.table)
library(dtplyr) # Requires old version 0.0.3; code breaks with 1.0.0
  # Install with remotes::install_version("dtplyr", version = "0.0.3", repos = "http://cran.us.r-project.org")
library(magrittr)
library(here)

#############
# FUNCTIONS #
#############
source(here::here("scripts", "myfunctions.R"))

# The by year data I have going all the way back to 2000
#  (it ends in 2011 but using the overlap I confirmed that it corresponds to last bimester of each year,
#   so I can combine this with the data for more recent years)
read_cards <- function(x) {
  a <- read.dbf(x) %>% 
    lowercase_names() %>% 
    as.data.table()
  a[, year := basename(x) %>% str_extract("[0-9]{4}")]
}
byyear_dbfs <- list.files(
  here::here("data", "Prospera", "by_year"),
  pattern = "\\.dbf",
  full.names = TRUE
)
# test
# x <- read_cards(byyear_dbfs[[1]])
cards_byyear <- byyear_dbfs %>% map(read_cards)
cards_byyear %<>% rbindlist()

cards_byyear[, localidad := str_c(
  str_pad(cve_edo, width = 2, pad = "0"),
  str_pad(cve_mun, width = 3, pad = "0"),
  str_pad(cve_loc, width = 4, pad = "0")
)]
cards_byyear %>% setorder(year, localidad)

# merge with population, and check when the urban localities started to receive the program
iter <- readRDS(here::here("proc", "iter2010.rds"))
cards_byyear %<>% merge(iter, by = "localidad", all.x = TRUE, all.y = FALSE)
cards_byyear[is.na(pobtot)] %>% tabcount(localidad) # 9464
cards_byyear[is.na(pobtot), .GRP, by = "localidad"]
  # based on their numbers, look to be small localities that no longer exist
  # confirmed by spotchecking a few, e.g. 010010129 listed as "inactiva" https://bit.ly/2O0lgH2
cards_byyear[pobtot > 15000] %>% tabcount(localidad) # 609
cards_byyear %>% tab(year)
cards_byyear[pobtot > 15000] %>% tab(year) 
#     year   N prop cum_prop
#  1: 2011 607 0.10     0.10
#  2: 2010 604 0.10     0.20
#  3: 2009 603 0.10     0.30
#  4: 2008 602 0.10     0.40
#  5: 2007 599 0.10     0.50
#  6: 2006 598 0.10     0.60
#  7: 2005 596 0.10     0.70
#  8: 2004 572 0.09     0.79
#  9: 2003 489 0.08     0.87
# 10: 2002 488 0.08     0.95
# 11: 2001 255 0.04     1.00
# 12: 2000  19 0.00     1.00
# so at a minimum will need to start at 2002, maybe 2004 or 2005

cards_byyear %>% saveRDS(here::here("proc", "cards_byyear.rds"))
cards_byyear[pobtot > 15000] %>% saveRDS(here::here("proc", "cards_byyear_urban.rds"))
