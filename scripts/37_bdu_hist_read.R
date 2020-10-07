# READ IN BDU DATA
#  Sean Higgins

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
bdu_hist <- readRDS(here::here("data", "BDU", "bdu_historico_sean.rds"))
nrow(bdu_hist) 

# Variable types
bdu_hist %>% map(class) %>% unlist()
fac_to_chrs <- c(
  "fec_val",
  "movimiento",
  "poblacion",
  "cp",
  "asig_cat_credito",
  "asig_cat_debito",
  "obs_inst",
  "obs_desp",
  "institucion"
)
fac_to_ints <- c(
  "giro",
  "grupo",
  "cat_credito",
  "cat_debito"
)
for (myvar in fac_to_chrs) {
  bdu_hist[, eval(myvar) := check_convert(eval(parse(text = myvar)), as.character)]
}
for (myvar in fac_to_ints) {
  bdu_hist[, eval(myvar) := check_convert(eval(parse(text = myvar)), fac_to_int)]
}
stopifnot(!any(map(bdu_hist, is.factor))) # i.e. all columns are not factors 

# Munging
bdu_hist[, same_cat := (cat_credito == cat_debito)]
bdu_hist[, .N, by = same_cat] #tabulate
bdu_hist[, mean(same_cat, na.rm = TRUE)] #mean 95%
bdu_hist[same_cat == FALSE] # just to look

# Dates
bdu_hist[, date := ymd(str_sub(fec_val,1,10))] 
  # str_sub is to cut the HMS (not present for all obs; o.w. fail to parse some)
bdu_hist[, num_date := as.numeric(date)] 
setorder(bdu_hist, date)

# READ IN MCC CODE DESCRIPTIONS
mcc <- fread(here::here("data", "MCC", "mcc_codes.csv"), 
  encoding = "UTF-8"
) # fast read as data.table
mcc[, c("mcc_descrip", "mcc_short") := list(str_sub(irs_description, 1, 60), str_sub(irs_description, 1, 25))] # 
mcc[, c(
  "edited_description",
  "combined_description",
  "usda_description",
  "irs_description",
  "irs_reportable") :=
    c(NULL, NULL, NULL, NULL, NULL)
  ]

# categoria CODES
cats <- tribble( # enter manually
  ~categoria, ~cat_descrip,
  63, "Agencias de viajes",
  76, "Agregadores",
  71, "Aseguradores",
  20, "Beneficencia",
  40, "Colegios y Universidades",
  51, "Comida Rapida",
  21, "Educacion basica",
  65, "Entretenimiento",
  54, "Estacionamientos",
  52, "Farmacias",
  30, "Gasolineras",
  41, "Gobierno",
  50, "Grandes Superficies",
  23, "Guarderias",
  72, "Hospitales",
  64, "Hoteles",
  22, "Medicos y dentistas",
  26, "Miscelanea",
  75, "Otros",
  53, "Peaje",
  24, "Refacciones y ferreterias",
  62, "Renta de autos",
  73, "Restaurantes",
  25, "Salones de belleza",
  60, "Supermercados",
  70, "Telecomunicaciones",
  66, "Transporte aereo",
  61, "Transporte terrestre de pasajeros",
  74, "Ventas al menudeo"
) %>% 
  arrange(categoria)

# Read in movimientos catalog
movimientos <- fread(here::here("data", "BDU", "cat_movimientos.csv"))  
movimientos <- movimientos %>% 
  select(-matches(".*[0-9]+")) %>%  # remove blank additional columns which read_csv marks X3 and fread marks as V3, etc.
  rename(descrip_movimiento = descripcion) 

# Merge
bdu_hist <- merge(bdu_hist, mcc, 
  by.x = "giro",
  by.y = "mcc",
  all.x = TRUE,
  all.y = FALSE
) # left_join
bdu_hist <- merge(bdu_hist, cats, 
  by.x = "cat_credito",
  by.y = "categoria",
  all.x = TRUE,
  all.y = FALSE
) # left_join
bdu_hist <- merge(bdu_hist, movimientos, 
  by = "movimiento",
  all.x = TRUE,
  all.y = FALSE
) # left_join

# BY CATEGORIA
bdu_hist %>% tab(cat_credito, cat_descrip)

# BY MCC
bdu_hist %>% tab(giro, mcc_descrip) %>% head(40)

# BY CATEGORIA x MCC
bdu_hist %>% tab(cat_credito, cat_descrip, giro, mcc_descrip)

# BY MOVIMIENTO
bdu_hist[institucion != "DES"] %>% tab(movimiento, descrip_movimiento) 

# BY MOVIMIENTO x INSTITUCION
crosstab <- lapply(unique(bdu_hist$institucion), function(x) {
  bdu_hist[institucion==x] %>% tab(movimiento,descrip_movimiento)
})
names(crosstab) <- unique(bdu_hist$institucion)
crosstab

# SAVE
saveRDS(bdu_hist, here::here("proc", "bdu_hist.rds"))
