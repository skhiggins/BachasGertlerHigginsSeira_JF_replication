# Convert raw data from Prospera from .sav to .dta

############
# PACKAGES #
############
library(haven)
library(tidyverse)
library(magrittr)
library(here)

########################
# PRELIMINARY PROGRAMS #
########################
sav_to_dta <- function(x) {
  a <- read_spss(here::here("data", "ENCASDU", x))
  names(a) %<>% map(str_to_lower) 
  names(a) %<>% map(~ str_replace(.x, "_\\$", ""))
  
  dta <- x %>% 
    str_replace(".sav", ".dta") %>% 
    str_replace(" ", "_") %>% 
    str_replace("ó", "o") %>% 
    str_to_lower()
  print(dta)
  
  # Was getting error in some of the data sets. 
  # Appears this is a bug in write_dta that was never fixed: https://github.com/tidyverse/haven/issues/343
  #  Error: Stata only supports labelling with integers.
  #  Problems: `h3a25a`, `h3a26a` 
  # To solve this issue, remove labels from data
  a %<>% zap_labels()
  
  a %>% write_dta(here::here("proc", dta))
}

###########
# CONVERT #
###########
encasdu <- list.files(path = here::here("data", "ENCASDU"), pattern = "*\\.sav")
encasdu %>% walk(sav_to_dta)
