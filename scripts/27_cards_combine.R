# COMBINE OLDER AND NEWER PROSPERA DATA ON FAMILIES AND PAYMENT TYPE OVER TIME
#  Sean Higgins

############
# PACKAGES #
############
library(tidyverse)
library(here)

#############
# FUNCTIONS #
#############
source(here::here("scripts", "myfunctions.R"))

########
# DATA #
########
fams_prosp_early <- readRDS(here::here("proc", "fams_prosp.rds")) # cards_read.R
fams_prosp <- readRDS(here::here("proc", "fams_prosp_2015plus.rds")) # cards_read_2015plus.R

fams_prosp_combined <- bind_rows(fams_prosp_early, fams_prosp)
fams_prosp_combined %>% tab(year, bim) %>% arrange(year, bim) %>% print_all() # 20076 to 20171

# SAVE
fams_prosp_combined %>% saveRDS(here::here("proc", "fams_prosp_combined.rds"))
