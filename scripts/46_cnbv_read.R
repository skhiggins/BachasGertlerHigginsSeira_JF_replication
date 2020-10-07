# READ CNBV DATA ON NUMBER OF CARDS, BANK BRANCHES, ETC.

# PACKAGES
library(tidyverse)
library(data.table)
library(dtplyr) # Requires old version 0.0.3; code breaks with 1.0.0
  # Install with remotes::install_version("dtplyr", version = "0.0.3", repos = "http://cran.us.r-project.org")
library(pbapply)
library(readxl)
library(assertthat)
library(zoo) # for na.locf
library(here)

# PRELIMINARIES
# Create a shorthand of the dl_producto_financiero variable for reshaping
# (for the newer .xlsx files)
producto_key <- tribble(
  ~dl_producto_financiero, ~product,
  "Número de Terminales Punto de Venta (TPV)", "pos_number",        
  "Número de Transacciones en Cajeros Automáticos", "atm_transactions",   
  "Número de Establecimientos con TPV", "pos_businesses",               
  "Número de Personal Contratado por la Entidad", "people_contracted",     
  "Número de Transacciones en TPV", "pos_transactions",                    
  "Número de Cajeros Automáticos", "atm_number",                    
  "Número de Personal Contratado por Terceros", "people_terceros",       
  "Número de Contratos de Tarjeta de Débito", "cards_debit",         
  "Número de Contratos de Tarjetas de Crédito", "cards_credit",       
  "Número de Sucursales", "branch_number",                             
  "Núm. Contr.  para Trans. a través del Tel. Celular", "mobile_money" 
)

# Same shorthand for the sheet names
# (for the newer .xls files)
sheet_key <- tribble(
  ~sheet_name, ~product,
  "Num de Transac en TPV", "pos_transactions",
  "Num de Sucursales", "branch_number",
  "Num de Contratos de TC", "cards_credit",
  "Num de Cajeros Automaticos", "atm_number",
  "Num de TPV", "pos_number",
  "Num de Transac en Cajeros Aut", "atm_transactions",
  "Num de Est con TPV", "pos_businesses",
  "Num de Contratos con TD", "cards_debit",
  "Num de Pers Cont por la Inst", "people_contracted",
  "Num de Pers Cont por Terceros", "people_terceros"
)  

sheet_key_old <- tribble(
  ~sheet_name, ~product,
  "Sucursales", "branch_number",
  "Contratos tarjetas crédito", "cards_credit",
  "Cajeros Automáticos", "atm_number",
  "Número tarjetas débito", "cards_debit",
  "Personal contratado por Inst", "people_contracted",
  "Personal prestadora de Serv", "people_terceros" 
)

# FUNCTIONS
source(here::here("scripts", "myfunctions.R"))

# Note: two major formats of the CNBV files:
#  i) xls are the older ones where each
#   sheet of the Excel corresponds to a different variable and format is harder to
#   manage
# ii) xlsx are newer ones with a hidden sheet that has all the data in long format
# Note: pre-201104 is a different format entirely
cnbv_read_all <- function(myfile, start, change, exclude, ...) {
  print(myfile)
  yearmonth <- str_extract(myfile, "[0-9]{6}")
  if ((as.integer(yearmonth) < as.integer(start)) | (yearmonth %in% exclude)) {
    return(NULL) # those ones have a different format and no INEGI mun code
  } 
  if (str_detect(myfile, "xls$")) { # ends with xls (not xlsx)
    if (as.integer(yearmonth) < change) {
      cnbv_read_xls(myfile, old = TRUE, ...)
    } else {
      cnbv_read_xls(myfile, ...)
    }
  } else {
    cnbv_read_xlsx(myfile, ...)
  }
}

cnbv_read_sheet <- function(sheet_key_row, myfile, aggregation) {
  var <- sheet_key_row[2]
  cnbv <- read_excel(
    here::here("data", "CNBV", myfile), 
    sheet = sheet_key_row[1], 
    skip = 1 # note: the column names are going to be 
  ) 

  cnbv <- cnbv[2:nrow(cnbv), ] %>% # get rid of first row
    tbl_dt() 
  
  # Remove results for other banks (might use later)
  cnbv <- cnbv[, 1:4]
  names(cnbv) <- c("state", "localidad", "name_localidad", "total")
  
  # Fill in localidad for all corresponding localities
  cnbv[, ":="(localidad = na.locf(localidad) %>% str_sub(start = 4), 
    state = na.locf(state)
  )]
  cnbv[, municipio := str_sub(localidad, 1, 5)]
  
  # Remove the rows that are state totals
  cnbv <- cnbv[!str_detect(state, "Total")]

  # Sum across all localities within municipality
  if (aggregation == "municipio") {
    cnbv <- cnbv[, .(total = sum(total)), by = "municipio"]
    names(cnbv) <- c(aggregation, var)
  }
  
  return(cnbv)
}

cnbv_read_xls <- function(myfile, aggregation = "municipio", old = FALSE) {
  yearmonth <- str_extract(myfile, "[0-9]{6}")
  if (old) { # old = TRUE for the older (pre-2011) format
    sheet_key_touse <- sheet_key_old
  } else {
    sheet_key_touse <- sheet_key
  }
  cnbv_as_list <- sheet_key_touse %>% apply(1, cnbv_read_sheet, 
    myfile = myfile, aggregation = aggregation
  )
  
  # Now need to merge them all together
  cnbv_wide <- cnbv_as_list %>% reduce(left_join, by = aggregation)
  
  # NA to 0
  cnbv_wide <- cnbv_wide[, lapply(.SD, na_to_0)]
  
  # Additional vars
  cnbv_wide[, cve_periodo := as.integer(yearmonth)]
  cnbv_wide[, year := str_sub(yearmonth, 1, 4)]
  cnbv_wide[, month := str_sub(yearmonth, 5, 6)]
  
  return(cnbv_wide)
} 

cnbv_read_xlsx <- function(myfile, aggregation = "municipio") {
  yearmonth <- str_extract(myfile, "[0-9]{6}")
  if (yearmonth == "201312") {
    mysheet <- 1
  } else {
    mysheet <- 2
  }
  cnbv <- read_excel(
    here::here("data", "CNBV", myfile),
    sheet = mysheet
  ) %>% as.data.table()
  
  # Fix names in problem files (just 201312 so far)
  if (names(cnbv)[[1]] != "cve_periodo") {
    cnbv[, Periodo := NULL]
    names(cnbv) <- c(
      "cve_periodo", 
      "cve_inegi", 
      "dl_estado", 
      "dl_municipio",
      "dl_localidad",
      "nombre_publicacion",
      "cve_tipo_informacion",
      "dl_producto_financiero",
      "dat_num_total", 
      "dat_saldo_producto",
      "subreporte"
    )
  }
  
  cnbv[, .N] # 101837
  
  # Clean
  cnbv[, localidad := 
    cve_inegi %>% as.character() %>% str_sub(start = 4) # cuts the first 3 "484"
  ]
  cnbv[, municipio := str_sub(localidad, 1, 5)]
  cnbv %>% tab(dl_producto_financiero)

  cnbv <- cnbv %>% merge(producto_key, by = "dl_producto_financiero")
  # Check it:
  cnbv %>% tab(product)
  
  # Reshape wide, by locality by bank
  cnbv_loc_bank <- cnbv %>% dcast(cve_periodo + localidad + municipio + nombre_publicacion ~ product,
    value.var = "dat_num_total", fun.aggregate = sum
  )
    # fun.aggregate = sum because multiple observations per 
    #  locality by bank by product.
    # Note: the reason is that these are reported by the banks at a 
    #  more disaggregated level (clave municipio SITI, not same as 
    #  INEGI municipio). Confirmed that their pivot
    #  tables in the Excel are summing across these.

  # Sum across all banks in locality/municipality
  cnbv_wide <- cnbv_loc_bank[, lapply(.SD, sum), 
    by = c("cve_periodo", aggregation),
    .SDcols = producto_key$product # variable names to sum
  ]  
  
  cnbv_wide <- cnbv_wide[, ":="(
    year = str_sub(cve_periodo, 1, 4),
    month = str_sub(cve_periodo, 5, 6)
  )]
  
  if (aggregation == "municipio") {
    cnbv_wide[, "localidad" := NULL]
  }
}

cnbv_files <- list.files(
  here::here("data", "CNBV"), pattern = "BM_Operativa"
  # downloaded with scrape_cnbv.ipynb
) %>% sort() # to put in order
cnbv_files

cnbv_all <- cnbv_files %>% 
  pblapply(cnbv_read_all, start = "200812", change = "201104", exclude = "201103")

names(cnbv_all) <- cnbv_files %>% map_chr(
  function(x) str_replace(x, ".xls*", "")
) 

# look at results:
for (i in seq_along(cnbv_all)) {
  print(cnbv_all[[i]])
}

# remove null periods:
old_length <- length(cnbv_all)
old_length_nulls <- sum(sapply(cnbv_all, is.null)) 
cnbv_all <- cnbv_all[-which(sapply(cnbv_all, is.null))]
assert_that(length(cnbv_all) == old_length - old_length_nulls)

# put them into one big data.table
cnbv_all <- cnbv_all %>% rbindlist(use.names = TRUE, fill = TRUE) # older didn't have mobile_money
cnbv_all

# Make sure it worked:
cnbv_all %>% distinct(municipio)   %>% .[, .N] # 2461
cnbv_all %>% distinct(cve_periodo) %>% .[, .N] # 92

# SAVE
cnbv_all %>% saveRDS(here::here("proc", "cnbv_mun.rds"))
