# Get data set with postal code and corresponding municipality

# PACKAGES 
library(tidyverse)
library(data.table)
library(dtplyr) # Requires old version 0.0.3; code breaks with 1.0.0
  # Install with remotes::install_version("dtplyr", version = "0.0.3", repos = "http://cran.us.r-project.org")
library(magrittr)
library(here)
 
# FUNCTIONS
source(here::here("scripts", "myfunctions.R"))

# DATA
cp <- read_delim(here::here("data", "SEPOMEX", "CPdescarga.txt"),
  delim = "|", skip = 1)
cp %>% nrow() # 144,958

cp <- cp %>% 
  mutate(municipio = str_c(c_estado, c_mnpio)) 

cp %>% distinct(municipio) %>% nrow() # 2455
n_cp <- cp %>% distinct(d_codigo) %>% nrow() 
n_cp # 32,120

# Take a look
cp %>% arrange(municipio) %>% select(d_codigo, municipio, everything()) 

cp_mun <- cp %>% distinct(d_codigo, municipio) %>% as.data.table()
cp_mun[, count := .N, by = "d_codigo"][count>1] # one zip code spans two municipios

# For now drop it since only one
cp_mun <- cp_mun %>% arrange(d_codigo, municipio) %>% distinct(d_codigo, .keep_all = TRUE)
stopifnot(n_cp==nrow(cp_mun))

cp_mun %<>% rename(cp = d_codigo) # for merge

# SAVE
cp_mun %>% saveRDS(here::here("proc", "cp_mun.rds"))
