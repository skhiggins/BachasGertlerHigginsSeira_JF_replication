# READ IN .dbf FILES WITH NUMBER OF FAMILIES AND PAYMENT TYPE (e.g. DEBIT CARD) BY LOCALITY
#  FOR 2015 AND BEYOND (DIFFERENT DATA FORMAT)
# Sean Higgins

############
# PACKAGES #
############
library(foreign)
library(tidyverse)
library(stringr)
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
dbfs <- list.files( # 2015-2016 (different format)
  here::here("data", "Prospera"), 
  pattern = "localidades_punto_entrega_bim_op_[0-9]{1}_[0-9]{4}\\.dbf$",
    # have to be exact to avoid reading in the SIN HAMBRE ones
  recursive = TRUE, 
  ignore.case = TRUE,
  full.names = TRUE
)

read_clean_fams_prosp <- function(x) { 
  print(x)
  a <- read.dbf(x, as.is = TRUE) %>% 
    as_tibble() %>% 
    select(-starts_with("X"))
  a %<>% lowercase_names()
  yearmonth <- basename(x) %>% 
    str_replace("localidades_punto_entrega_bim_op_", "") %>% 
    str_replace("\\.dbf$", "")
  year <- str_sub(yearmonth, start = 3, end = 6) # note the different file name format
    # (in later files it's b_yyyy, where b is bimester and yyyy is year)
  bim <- str_sub(yearmonth, start = 1, end = 1)
  
  # Rename variables
  a %<>% rename(
    instpaga = institucio, 
    descripcio = nom_inst,
    cve_edo = f_estado,
    nom_edo = f_nom_edo,
    cve_mun = f_municipi,
    nom_mun = f_nom_mun,
    cve_loc = f_loc, 
    nom_loc = f_nom_loc, 
    fams = fam_emitid # note newer data also has monto_emit (in pesos)
      # but not using here since I only have the amounts data since 2013 (double check)
  )
  a %<>% select(
    instpaga,
    descripcio,
    cve_edo,
    nom_edo,
    cve_mun,
    nom_mun,
    cve_loc,
    nom_loc,
    fams
  )
  a %<>% mutate(year = year, bim = bim)
  a
}

fams_prosp <- dbfs %>% 
  map(read_clean_fams_prosp) %>% 
  bind_rows()

# Look at values of state code (noticed an issue)
fams_prosp %>% group_by(cve_edo) %>% 
  count() %>% 
  arrange(cve_edo) %>% 
  print_all() # one problem: one coded as 0

fams_prosp <- fams_prosp %>% 
  mutate(cve_edo = ifelse(cve_edo == 0, 1, cve_edo))
#  Make sure it worked:
assert_that(all(fams_prosp$cve_edo != 0))

# Tab by payment type (most recent bimester)
max_bim <- fams_prosp %>% filter(year == max(year)) %>% 
  summarize(max(bim)) %>% as.numeric()
fams_prosp %>%
  filter(bim == max_bim & year == max(year)) %>% 
  group_by(instpaga, descripcio) %>% 
  summarize(sum_fams = sum(fams), n_loc = n()) %>% 
  arrange(desc(sum_fams))

fams_prosp <- fams_prosp %>% mutate(
  debit_cards = ifelse(instpaga == 12, fams, 0), 
  localidad = str_c(
    str_pad(as.character(cve_edo), width = 2, pad = "0"),
    str_pad(as.character(cve_mun), width = 3, pad = "0"),
    str_pad(as.character(cve_loc), width = 4, pad = "0")
  )
)

# GRAPH: EXPLORE MEXICO CITY
state_sum <- fams_prosp %>% 
  mutate(month = 2*as.numeric(bim) - 1,
    date = lubridate::make_date(year, month, 1)
  ) %>% 
  group_by(cve_edo, date) %>% 
  summarize(debit_cards = sum(debit_cards), fams = sum(fams))

state_sum %>% filter(cve_edo == 09) %>% 
  ggplot(aes(y = debit_cards, x = date)) +
    geom_line()

state_sum %>% group_by(date) %>% 
  summarize(debit_cards = sum(debit_cards), fams = sum(fams)) %>% 
  ggplot(aes(y = debit_cards, x = date)) +
    geom_line()

state_sum %>% filter(cve_edo == 09) %>% 
  ggplot(aes(y = fams, x = date)) +
  geom_line()

state_sum %>% group_by(date) %>% 
  summarize(debit_cards = sum(debit_cards), fams = sum(fams)) %>% 
  ggplot(aes(y = fams, x = date)) +
  geom_line()

# SAVE
fams_prosp %>% saveRDS(here::here("proc", "fams_prosp_2015plus.rds"))
