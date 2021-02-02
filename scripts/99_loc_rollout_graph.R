# MAP OF ROLLOUT ACROSS TIME AND SPACE
#  Sean Higgins

# PACKAGES
library(sf)
library(tidyverse)
library(data.table)
library(dtplyr) # Requires old version 0.0.3; code breaks with 1.0.0
  # Install with remotes::install_version("dtplyr", version = "0.0.3", repos = "http://cran.us.r-project.org")
library(magrittr)
library(colorblindr)
library(here)

# FUNCTIONS
source(here::here("scripts", "myfunctions.R"))

# PRELIMINARY
textsize <- 14
my_maptheme <- theme(
  plot.margin = margin(t = 0, r = -0.5, l = -0.5, b = 0, unit = 'cm'),
  legend.title = element_blank(),
  legend.position = c(0.8, 0.8), # if on right 
  legend.direction = "horizontal",
  legend.margin = margin(t = 0, r = 0.5, b = 0, l = 0, unit = 'cm'),
  plot.background = element_blank()
)

# Shape files for municipalities
states <- list.files(here::here("data", "shapefiles", "INEGI"))

# remove blank.txt 
states <- states[states != "blank.txt"]

read_shapefiles <- function(state, type) {
  read_sf(dsn = here::here("data", "shapefiles", "INEGI", state), 
    layer = str_c(state, type) 
  ) %>% st_transform(4326) # longlat
}

loc_map_list <- states %>% map(read_shapefiles, 
  type = "_localidad_urbana_y_rural_amanzanada")
loc_map <- do.call(rbind, loc_map_list)
rm(loc_map_list) # for efficiency

state_map_list <- states %>% map(read_shapefiles, type = "_entidad")
state_map <- do.call(rbind, state_map_list)

# Bimester of switch
cards_pob <- readRDS(here::here("proc", "cards_pob.rds")) # prospera_panel.R

# Restrict to urban
cards_pob_urb <- cards_pob[pobtot > 15000] %>% tbl_dt()
  # only the ones that switch to cards (300)
cards_pob_urb %>% as_tibble() %>% tab(bimswitch)
cards_pob_urb %<>% filter(year_switch < 2012 | year_switch == 2012 & bim_switch < 4) # 11 out of 300 locs have >2013
  # these were not part of randomized rollout (need to verify if late 2012 were)
cards_pob_urb %>% as_tibble() %>% tab(bimswitch)

# Map to a bimester counter
years <- seq(cards_pob_urb %>% as.data.table() %$% min(year_switch), cards_pob_urb %>% as.data.table() %$% max(year_switch), by = 1)
yearbim <- function(x, n) rep(x, n) %>% cbind(seq(1, n)) %>% as.data.frame()
bim_mapping <- years %>% map(yearbim, n = 6) %>% rbindlist()
bim_mapping %<>% cbind(1:nrow(bim_mapping))
names(bim_mapping) <- c("year", "bim", "bim_num")

cards_pob_urb %<>% as.data.table() %>% merge(bim_mapping,
  by.x = c("year_switch", "bim_switch"), by.y = c("year", "bim"), 
  all.x = TRUE, all.y = FALSE  
) %>% tbl_dt() %>% 
  rename(bimswitch_num = bim_num) %>% 
  mutate(bimswitch_frac = cards_pob_urb %$% min(year_switch) + (bimswitch_num - 1)/6)

# Merge GIS with bimswitch locality level data
loc_cards <- merge(loc_map, cards_pob_urb %>% as.data.table(), by.x = "CVEGEO", by.y = "localidad", 
  all = FALSE
)
loc_cards %>% nrow() # 259

loc_card_centroids <- loc_cards %>%
  st_transform(29101) %>% # EPSG:29101 because st_centroid doesn't work with lat/long; see https://stackoverflow.com/questions/46176660/how-to-calculate-centroid-of-polygon-using-sfst-centroid
  st_centroid() %>% 
  st_transform(., '+proj=longlat +ellps=GRS80 +no_defs') # back to lat/long

map_color <- ggplot() + 
  geom_sf(data = state_map, fill = NA, color = "lightgray") + # state outlines
  geom_sf(data = loc_card_centroids, aes(color = bimswitch_frac)) + 
  scale_color_viridis_c(direction = -1, breaks = c(2009, 2010, 2011, 2012)) + 
  # scale_color_gradient(low = "lightblue", high = "blue") + 
  guides(color = guide_colorbar(# barwidth = 0.5, barheight = 10, # if vertical
    barwidth = 12, barheight = 0.5, # if horizontal 
    label.theme = element_text(size = textsize, angle = 0),
    ticks = FALSE
  )) +
  theme_void() +
  my_maptheme
ggsave(here::here("graphs", "rollout.eps"), map_color, width = 8, height = 5)

map_bw <- map_color %>% edit_colors(desaturate)
ggsave(here::here("graphs", "rollout_bw.eps"), map_bw, width = 8, height = 5) # LOH, not working
