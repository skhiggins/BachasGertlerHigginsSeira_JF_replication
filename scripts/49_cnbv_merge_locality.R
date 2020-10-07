# PREPARE LCOALITY-LEVEL CNBV DATA FROM SELECT PERIODS FOR DISCRETE TIME HAZARD
#  Sean Higgins

# Note: before 200812, CNBV data had a different locality codes
#  --> try merging on locality name (string)

# PACKAGES
library(haven)
library(tidyverse)
library(data.table)
library(dtplyr) # Requires old version 0.0.3; code breaks with 1.0.0
  # Install with remotes::install_version("dtplyr", version = "0.0.3", repos = "http://cran.us.r-project.org")
library(magrittr)
library(wrapr)
library(readxl)
library(assertthat)
library(zoo) # for na.locf
library(here)

# FUNCTIONS
source(here::here("scripts", "myfunctions.R"))

cnbv_read_sheet <- function(sheet_name, myfile, superold = FALSE) {
  cnbv <- read_excel(
    here::here("data", "CNBV", myfile), 
    sheet = sheet_name, 
    skip = 1 # note: the column names are going to be 
  ) 

  cnbv <- cnbv[2:nrow(cnbv), ] %>%  # get rid of first row
    tbl_dt() %>% 
    as.data.table()
    
  # Remove results for other banks (might use later)
  cnbv <- cnbv[, 1:4]
  names(cnbv) <- c("state", "localidad", "name_localidad", "total")
  
  # Fill in localidad for all corresponding localities
  if (superold) {
    cnbv[, ":="(localidad = na.locf(localidad), state = na.locf(state))]    
  } else {
    cnbv[, ":="(localidad = na.locf(localidad) %>% str_sub(start = 4), 
      state = na.locf(state)
    )]
    cnbv[, municipio := str_sub(localidad, 1, 5)]
  }
  
  # Remove the rows that are state totals
  cnbv <- cnbv[!str_detect(state, "Total")]
  
  # Remove non-data rows
  cnbv <- cnbv[!str_detect(state, "Notas")]

  return(cnbv)
}

add_year_toname <- function(x, year, except) {
  if (x %in% except) return(x)
  str_c(x, "_", year)
}

# Was getting an error trying to read in the file using the sub-functions so just do this:
cnbv_200612 <- "BM_Operativa_200612.xls" %.>% 
  cnbv_read_sheet("Número de sucursales ", myfile = ., superold = TRUE) %>% 
  .[, in_ := 1] # for merge
names(cnbv_200612) %<>% map_chr(add_year_toname, year = 2006, except = "name_localidad")

cnbv_200812 <- "BM_Operativa_200812.xls" %.>% 
  cnbv_read_sheet("Sucursales", myfile = ., superold = FALSE) %>% 
  .[, in_ := 1]
names(cnbv_200812) %<>% map_chr(add_year_toname, year = 2008, except = "name_localidad")

cnbv_merged <- merge(cnbv_200612, cnbv_200812, 
  all.x = TRUE, all.y = TRUE, # full_join
  by = "name_localidad"
)
cnbv_merged %>% tab(in__2008) # 84% merged, pretty good
cnbv_merged %>% tab(in__2006) # 83%

cnbv_merged[is.na(in__2008)] %>% print_all()
  # Note: Mexico City only has one entry in 2006...
cnbv_200612[state_2006=="Distrito Federal"]

cnbv_merged[is.na(in__2006)] %>% print_all()

total_cols <- cnbv_merged %>% select_colnames("total_")
cnbv_branch_mun <- cnbv_merged[, lapply(.SD, sum, na.rm = TRUE), .SDcols = total_cols, by = "municipio_2008"]
  # will remove if =0 because that means all were NA
# cnbv_branch_mun[, total_2006 := ifelse(total_2006 == 0, NA, total_2006)]
  # So what I can do is put 0s when they have none and then put a missing dummy

cnbv_branch_mun <- cnbv_branch_mun[!is.na(municipio_2008)]

# Rename variables
cnbv_branch_mun[, ":="(
  branches_2006 = total_2006,
  branches_2008 = total_2008,
  total_2006 = NULL,
  total_2008 = NULL,
  municipio = municipio_2008,
  municipio_2008 = NULL
)]
branch_vars <- cnbv_branch_mun %>% select_colnames("branches_")
ln_branch_vars <- branch_vars %>% map_chr(function(x) str_c("ln_", x))
cnbv_branch_mun[, (ln_branch_vars) := lapply(.SD, log1p), .SDcols = branch_vars]

cnbv_branch_mun[, in_branches := 1] # for merge in later scripts

########################
# Number of savings accounts
# Was getting an error trying to read in the file using the sub-functions so just do this:
cnbv_accounts_200612 <- "BM_Operativa_200612.xls" %.>% 
  cnbv_read_sheet("Contratos de cuentas de ahorro ", myfile = ., superold = TRUE) %>% 
  .[, in_ := 1] # for merge
names(cnbv_accounts_200612) %<>% map_chr(add_year_toname, year = 2006, except = "name_localidad")

cnbv_accounts_200812 <- "BM_Operativa_200812.xls" %.>% 
  cnbv_read_sheet("Contratos cuenta ahorro", myfile = ., superold = FALSE) %>% 
  .[, in_ := 1]
names(cnbv_accounts_200812) %<>% map_chr(add_year_toname, year = 2008, except = "name_localidad")

cnbv_accounts_merged <- merge(cnbv_accounts_200612, cnbv_accounts_200812, 
  all.x = TRUE, all.y = TRUE, # full_join
  by = "name_localidad")
cnbv_accounts_merged %>% tab(in__2008) # 84% merged, pretty good
cnbv_accounts_merged %>% tab(in__2006) # 83%

cnbv_accounts_merged[is.na(in__2008)] %>% print_all()
  # Note: Mexico City only has one entry in 2006...
cnbv_accounts_200612[state_2006=="Distrito Federal"]

cnbv_accounts_merged[is.na(in__2006)] %>% print_all()

total_cols <- cnbv_accounts_merged %>% select_colnames("total_")
cnbv_accounts_mun <- cnbv_accounts_merged[, lapply(.SD, sum, na.rm = TRUE), .SDcols = total_cols, by = "municipio_2008"]
  # will remove if =0 because that means all were NA
# cnbv_branch_mun[, total_2006 := ifelse(total_2006 == 0, NA, total_2006)]
  # So what I can do is put 0s when they have none and then put a missing dummy

cnbv_accounts_mun <- cnbv_accounts_mun[!is.na(municipio_2008)]

cnbv_accounts_mun[, ":="(
  accounts_2006 = total_2006,
  accounts_2008 = total_2008,
  total_2006 = NULL,
  total_2008 = NULL,
  municipio = municipio_2008,
  municipio_2008 = NULL
)]
accounts_vars <- cnbv_accounts_mun %>% select_colnames("accounts_")
ln_accounts_vars <- accounts_vars %>% map_chr(function(x) str_c("ln_", x))
cnbv_accounts_mun[, (ln_accounts_vars) := lapply(.SD, log1p), .SDcols = accounts_vars]

cnbv_accounts_mun[, in_accounts := 1] # for merge in later scripts

########################
# Number of checking accounts
# Was getting an error trying to read in the file using the sub-functions so just do this:
cnbv_checking_200612 <- "BM_Operativa_200612.xls" %.>% 
  cnbv_read_sheet("Contratos de cuentas de cheques", myfile = ., superold = TRUE) %>% 
  .[, in_ := 1] # for merge
names(cnbv_checking_200612) %<>% map_chr(add_year_toname, year = 2006, except = "name_localidad")

cnbv_checking_200812 <- "BM_Operativa_200812.xls" %.>% 
  cnbv_read_sheet("Contratos cheques pers Fisica", myfile = ., superold = FALSE) %>% 
  .[, in_ := 1]
cnbv_checking_200812 %<>% tbl_dt() %>% 
  rename(checking_fisica = total) %>% 
  as.data.table()
cnbv_checkingmoral_200812 <- "BM_Operativa_200812.xls" %.>% 
  cnbv_read_sheet("Contratos cheques pers Moral", myfile = ., superold = FALSE) %>% 
  .[, in_ := 1]
cnbv_checkingmoral_200812 %<>% tbl_dt() %>% 
  rename(checking_moral = total) %>% 
  select(localidad, name_localidad, checking_moral) %>% 
  as.data.table()
cnbv_checking_200812 %<>% merge(cnbv_checkingmoral_200812, 
  all.x = TRUE, all.y = TRUE, # full_join
  by = c("localidad", "name_localidad")
)
checking_vars <- cnbv_checking_200812 %>% select_colnames("checking")
cnbv_checking_200812 <- cnbv_checking_200812[, (checking_vars) := lapply(.SD, na_to_0), .SDcols = checking_vars]

cnbv_checking_200812 %<>% tbl_dt() %>% 
  mutate(total = checking_fisica + checking_moral) %>% 
  as.data.table()
names(cnbv_checking_200812) %<>% map_chr(add_year_toname, year = 2008, except = "name_localidad")

cnbv_checking_merged <- merge(cnbv_checking_200612, cnbv_checking_200812, 
  all.x = TRUE, all.y = TRUE, # full_join
  by = "name_localidad"
)
cnbv_checking_merged %>% tab(in__2008) # 84% merged, pretty good
cnbv_checking_merged %>% tab(in__2006) # 83%

cnbv_checking_merged[is.na(in__2008)] %>% print_all()
  # Note: Mexico City only has one entry in 2006...
cnbv_checking_200612[state_2006=="Distrito Federal"]

cnbv_checking_merged[is.na(in__2006)] %>% print_all()

total_cols <- cnbv_checking_merged %>% select_colnames("total_")
cnbv_checking_mun <- cnbv_checking_merged[, lapply(.SD, sum, na.rm = TRUE), .SDcols = total_cols, by = "municipio_2008"]
  # will remove if =0 because that means all were NA
# cnbv_branch_mun[, total_2006 := ifelse(total_2006 == 0, NA, total_2006)]
  # So what I can do is put 0s when they have none and then put a missing dummy

cnbv_checking_mun <- cnbv_checking_mun[!is.na(municipio_2008)]

# Rename variables
cnbv_checking_mun[, ":="(
  checking_2006 = total_2006,
  checking_2008 = total_2008,
  total_2006 = NULL,
  total_2008 = NULL,
  municipio = municipio_2008,
  municipio_2008 = NULL
)]
account_vars <- cnbv_checking_mun %>% select_colnames("checking_")
ln_account_vars <- account_vars %>% map_chr(function(x) str_c("ln_", x))
cnbv_checking_mun[, (ln_account_vars) := lapply(.SD, log1p), .SDcols = account_vars]

cnbv_checking_mun[, in_checking := 1] # for merge in later scripts

# Number of ATMs
cnbv_atms <- "BM_Operativa_200812.xls" %.>% 
  cnbv_read_sheet("Cajeros Automáticos", myfile = ., superold = FALSE) %>% 
  .[, in_ := 1]
cnbv_atms <- cnbv_atms[, lapply(.SD, sum), .SDcols = "total", by = "municipio"]
cnbv_atms[, ":="(
  atm = total,
  total = NULL
)] # rename

##########################################################################################################
# SAVE
cnbv_branch_mun %>% saveRDS(here::here("proc", "cnbv_branch_mun.rds"))
cnbv_branch_mun %>% write_dta(here::here("proc", "cnbv_branch_mun.dta"))

cnbv_accounts_mun %>% saveRDS(here::here("proc", "cnbv_accounts_mun.rds"))
cnbv_accounts_mun %>% write_dta(here::here("proc", "cnbv_accounts_mun.dta"))

cnbv_checking_mun %>% saveRDS(here::here("proc", "cnbv_checking_mun.rds"))
cnbv_checking_mun %>% write_dta(here::here("proc", "cnbv_checking_mun.dta"))

cnbv_atms %>% saveRDS(here::here("proc", "cnbv_atms.rds"))
cnbv_atms %>% write_dta(here::here("proc", "cnbv_atms.dta"))

