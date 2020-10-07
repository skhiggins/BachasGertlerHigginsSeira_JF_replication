# READ IN .dbf FILES WITH NUMBER OF FAMILIES AND PAYMENT TYPE (e.g. DEBIT CARD) BY LOCALITY
#  AND COMBINE INTO ONE DATA SET
# Sean Higgins

# Note: formerly dbf_familias_loc.R; renamed for consistent file names

############
# PACKAGES #
############
library(foreign)
library(haven)
library(tidyverse)
library(assertthat)
library(here)

#############
# FUNCTIONS #
#############
source(here::here("scripts", "myfunctions.R"))

########
# DATA #
########
dbfs = list.files(here::here("data", "Prospera"), 
  pattern = "fams_prosp_[0-9]{5}\\.dbf$",
  recursive = TRUE,
  ignore.case = TRUE,
  full.names = TRUE
) 

read_clean_fams_prosp <- function(x) {
  a <- read.dbf(x, as.is = TRUE) %>% 
    as_tibble() %>% 
    select(-starts_with("X"))
  names(a) <- str_to_lower(names(a))
	if (anyNA(a$fams)) { # for the three problem files I also created csv versions
	  a <- read_csv(str_replace(x, "dbf|DBF", "csv"))
	  names(a) <- str_to_lower(names(a))
	}
  yearmonth <- basename(x) %>% 
    str_replace("fams_prosp_","") %>% 
    str_replace("\\.dbf$", "")
  year <- str_sub(yearmonth, start = 1, end = 4)
  bim <- str_sub(yearmonth, start = 5, end = 5)
  a <- a %>% 
    mutate(year = year, bim = bim)
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
fams_prosp %>% saveRDS(here::here("proc", "fams_prosp.rds"))
fams_prosp %>% select(-starts_with("nom_")) %>% # strings too long; leads to failure
  write_dta(here::here("proc", "fams_prosp.dta"))
