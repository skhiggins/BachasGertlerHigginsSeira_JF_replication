# CONVERT .dta OF ENOE (ALL SECTORS) TO .rds

# PACKAGES
library(haven)
library(tidyverse)
library(data.table)
library(dtplyr) # Requires old version 0.0.3; code breaks with 1.0.0
  # Install with remotes::install_version("dtplyr", version = "0.0.3", repos = "http://cran.us.r-project.org")
library(magrittr)
library(assertthat)
library(here)

# FUNCTIONS
source(here::here("scripts", "myfunctions.R")) # includes tabulator

# PRELIMINARIES
Sys.time() %>% print() # note log is automatic with R CMD BATCH

# DATA
enoe <- read_dta(here::here("proc", "enoe_all.dta")) %>% tbl_dt() 

# Make a baseline version to add as controls for debit cards paper
enoe_baseline <- enoe[year == 2008 & quarter == 1]

# SAVE
enoe %>% saveRDS(here::here("proc", "enoe_all.rds"))
enoe_baseline %>% saveRDS(here::here("proc", "enoe_baseline.rds"))

# WRAP UP
warnings() %>% print()
Sys.time() %>% print()
