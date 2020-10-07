# UNZIP DENUE DATA
#  Sean Higgins

# PACKAGES
library(tidyverse)
library(here)

# FUNCTIONS
source(here::here("scripts", "myfunctions.R"))

# DATA
to_unzip <- list.files(path = here::here("data", "DENUE", "2017"), 
  pattern = "_csv.zip$", # not the shapefiles which are "_shp.zip$"
  full.names = TRUE, 
  recursive = FALSE
)

# Unzip all the zip files  
to_unzip %>% walk(unzip, exdir = here::here("data", "DENUE", "2017"))
