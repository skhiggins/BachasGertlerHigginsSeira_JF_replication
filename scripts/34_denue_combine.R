# READ AND COMBINE DENUE DATA
#  Sean Higgins

# PACKAGES
library(tidyverse)
library(data.table)
library(dtplyr) # Requires old version 0.0.3; code breaks with 1.0.0
  # Install with remotes::install_version("dtplyr", version = "0.0.3", repos = "http://cran.us.r-project.org")
library(here)

# FUNCTIONS
source(here::here("scripts", "myfunctions.R"))

# DATA
folders <- list.dirs(path = here::here("data", "DENUE", "2017"),
  full.names = TRUE, 
  recursive = TRUE
)

folders <- folders[str_detect(folders, "conjunto_de_datos$")]

get_denue_csv <- function(x) {
  a <- list.files(path = x,
    pattern = "_.csv$",
    full.names = TRUE
  ) # note that each conjunto_de_datos folder has a .csv and a _.csv;
    #  looks like the same businesses in each file but _.csv might 
    #  have some additional rows so use that one
  if (length(a) != 1) {
    cat(x, " not length 1")
    return(NULL)
  }
  read_csv(a, col_types = cols(
    cod_postal = col_character(),
    numero_int = col_integer()
  ))
}

denue <- vector("list", length(folders))      
for (i in seq_along(folders)) {
  print(folders[[i]])
  denue[[i]] <- get_denue_csv(folders[[i]])
}
denue %>% map_lgl(is.null) %>% sum() # just 1 problem file
  # checked it out and it's because ß\they put a weird folder structure
  # with a separate folder for the ".csv" and the "_.csv"
  # so we are good to just drop this problem folder
# Drop the 1 null obs
orig_length <- length(denue)
denue <- denue[which(!map_lgl(denue, is.null))]
stopifnot(length(denue) == orig_length - 1)

# DEBUGGING
# check column type of cols that give problems
#  on rowbind
class <- vector("character", length(denue))
for (i in seq_along(denue)) {
  class[[i]] <- class(denue[[i]]$numero_int)
}
class

# Make it one big data.table
denue <- denue %>% bind_rows() %>% as.data.table()
#  number of rows
denue[, .N] # 7,165,165
setkey(denue, id)
setorder(denue, id)

# check for duplicate observations
denue[, N_byid := .N, by = "id"]
# denue[N_byid > 1] %>% View() # duplicate of same businesses

# Drop duplicate ids
denue <- denue %>% distinct(id, .keep_all = TRUE)
denue[, .N] # 5M

# SAVE
saveRDS(denue, here::here("proc", "denue.rds"))

