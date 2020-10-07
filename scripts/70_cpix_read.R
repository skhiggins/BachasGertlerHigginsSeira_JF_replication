# READ IN THE BANXICO MICRO CPI DATA

############
# PACKAGES #
############
library(tidyverse)
library(data.table)
library(dtplyr) # Requires old version 0.0.3; code breaks with 1.0.0
  # Install with remotes::install_version("dtplyr", version = "0.0.3", repos = "http://cran.us.r-project.org")
library(magrittr)
library(assertthat)
library(foreign)
library(haven)
library(here)

#############
# FUNCTIONS #
#############
source(here::here("scripts", "myfunctions.R"))

no_accents <- function(x) {
  x %>% 
    str_replace_all("á", "a") %>% 
    str_replace_all("é", "e") %>% 
    str_replace_all("í", "i") %>%
    str_replace_all("ó", "o") %>% 
    str_replace_all("ú", "u") %>% 
    str_replace_all("ñ", "n") %>% 
    str_replace_all("Á", "A") %>% 
    str_replace_all("É", "E") %>% 
    str_replace_all("Í", "I") %>%
    str_replace_all("Ó", "O") %>% 
    str_replace_all("Ú", "U") %>% 
    str_replace_all("Ñ", "N")    
    # can add more here as needed
}

########
# DATA #
########
cpix <- read_dta(here::here("data", "CPI", "INPC_02_14_Workhorse_MuniByMonth_02_14_d.dta")) %>% 
  lowercase_names %>% tbl_dt()
mun <- read.dbf(here::here("data", "INEGI", "cat_municipio_NOV2017.dbf"), as.is = TRUE) %>% 
  lowercase_names %>% tbl_dt() # raw municipality catalog from INEGI
  # (need this to get )

# Manually fix ones with weird characters

mun_nom_cols <- mun %>% select_colnames("nom_")
cpix_nom_cols <- cpix %>% select_colnames("nom")
mun[, (mun_nom_cols) := lapply(.SD, function(x) str_to_upper(no_accents(x))), 
  .SDcols = mun_nom_cols] # to merge
cpix[, (cpix_nom_cols) := lapply(.SD, function(x) str_to_upper(no_accents(x))), 
  .SDcols = cpix_nom_cols] # to merge

# Manually fix some state and municipality names that differ across sources
cpix_mun_key <- tribble(~nommun, ~nommun_renamed,
  "PAZ, LA", "LA PAZ", 
  "ECATEPEC", "ECATEPEC DE MORELOS",
  "  HUIXQUILUCAN", "HUIXQUILUCAN",
  "  LOS REYES", "LOS REYES",
  "NAUCALPAN", "NAUCALPAN DE JUAREZ",
  "TLAQUEPAQUE", "SAN PEDRO TLAQUEPAQUE",
  "YAUHQUEMECAN", "YAUHQUEMEHCAN",
  "MAGDALENA CONTRERAS, LA", "LA MAGDALENA CONTRERAS",
  "GUASTAVO A. MADERO", "GUSTAVO A. MADERO",
  "ALLENDE", "SAN MIGUEL DE ALLENDE",
  "MAGDALENA TLALTELULCO, LA", "LA MAGDALENA TLALTELULCO"
)

# Rename the states to match in two sources
mun_state_key <- tribble(~nom_ent, ~nom_ent_renamed,
  "VERACRUZ DE IGNACIO DE LA LLAVE", "VERACRUZ-LLAVE",
  "CIUDAD DE MEXICO", "DISTRITO FEDERAL",
  "QUERETARO", "QUERETARO DE ARTEAGA"
)
# Manually fix some municipality names in INEGI municipio data if name shorter in CPI
mun_mun_key <- tribble(~nom_mun, ~nom_mun_renamed,
  "HEROICA CIUDAD DE JUCHITAN DE ZARAGOZA", "JUCHITAN DE ZARAGOZA"  
)

cpix %<>% merge(cpix_mun_key, by = "nommun", all.x = TRUE, all.y = FALSE)
cpix[, nommun := ifelse(!is.na(nommun_renamed), nommun_renamed, nommun)]
cpix[, nommun_renamed := NULL]

mun %<>% merge(mun_state_key, by = "nom_ent", all.x = TRUE, all.y = FALSE)
mun[, nom_ent := ifelse(!is.na(nom_ent_renamed), nom_ent_renamed, nom_ent)]
mun[, nom_ent_renamed := NULL]
mun %<>% merge(mun_mun_key, by = "nom_mun", all.x = TRUE, all.y = FALSE)
mun[, nom_mun := ifelse(!is.na(nom_mun_renamed), nom_mun_renamed, nom_mun)]
mun[, nom_mun_renamed := NULL]

# Manually replace following Atkin Faber Gonzalez-Navarro do file
#  (municipality that merged with another)
cpix[, nommun := ifelse(noment == "MEXICO" & nommun == "LOS REYES", "LA PAZ", nommun)]

# Deal with the ones that still have weird UTF-8 characters
cpix[, nommun := ifelse(
  noment == "COAHUILA DE ZARAGOZA" & str_sub(nommun, 1, 3) == "ACU", 
  "ACUNA", nommun  
)] 
cpix[, nommun := ifelse(
  noment == "JALISCO" & str_detect(nommun, "TLAJOMULCO DE ZU"), 
  "TLAJOMULCO DE ZUNIGA", nommun  
)] 

# One municipality in State of Mexico was miscoded as Distrito Federal
cpix[, noment := ifelse(nommun == "CUAUTITLAN IZCALLI", "MEXICO", noment)]

cpix_ <- cpix %>% merge(mun, 
  by.x = c("noment", "nommun"), 
  by.y = c("nom_ent", "nom_mun"), 
  all.x = TRUE, all.y = FALSE)

# Check how well the merge did:
cpix_[!is.na(cve_mun), .N]/cpix_[, .N] 
  # 96% (was 79% before any manual corrections)
  # and the remaining 4% are missing nommun:
cpix_[is.na(cve_mun)] %>% tab(noment, nommun)
assert_that(cpix_[is.na(cve_mun) & nommun == "", .N] == cpix_[is.na(cve_mun), .N])
  # i.e. assert that all with is.na(cve_mun), not merged, have missing nommun (in CPI)
cpix_ <- cpix_[!is.na(cve_mun)]

# SAVE
cpix_ %>% names()
cpix_ %>% saveRDS(here::here("proc", "cpix.rds"))

# Baseline version to add as controls in debit cards paper
cpix_baseline <- cpix_[(year == 2008) & (month == 1)] # Jan 2008
cpix_baseline # Take a look
cpix_baseline %>% saveRDS(here::here("proc", "cpix_baseline.rds"))
