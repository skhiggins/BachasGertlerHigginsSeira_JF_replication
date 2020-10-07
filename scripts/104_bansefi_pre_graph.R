# BANSEFI ACCOUNT EVENT STUDY PRE-TRENDS
#  Sean Higgins

############
# PACKAGES #
############
library(haven)
library(tidyverse)
library(data.table)
library(dtplyr) # Requires old version 0.0.3; code breaks with 1.0.0
  # Install with remotes::install_version("dtplyr", version = "0.0.3", repos = "http://cran.us.r-project.org")
library(magrittr)
library(assertthat)
library(here)

#################
# PRELIMINARIES #
#################
source(here::here("scripts", "myfunctions.R"))

########
# DATA #
########
# Read in results from event study files
net_savings_ind_0 <- read_dta(here::here("proc", "net_savings_ind_0_w5.dta"))
ln_net_savings_ind_0 <- read_dta(here::here("proc", "net_savings_ind_0_ln.dta"))
N_withdrawals <- read_dta(here::here("proc", "N_withdrawals.dta"))

#########
# GRAPH #
#########
graph_pre_trends <- function(df, outcome, title_, y_limits,
  y_breaks = NULL,
  months_per_period = 4,
  label_by = 3,
  error_size = 0.5, # more visible for small panel graphs
  error_width = 0.4, # more visible for small panel graphs
  point_stroke = 0.75,
  width = 4,
  height = 4,
  x_expand = c(0.01, 0.01),
  y_expand = c(0.01, 0.01),
  y_accuracy = NULL,
  point_size = 2,
  add_lines = NULL,  
  max_period = 0,
  min_period = -36,
  title = "",
  xtitle = "",
  ytitle = "",
  filetype = "eps"
) {
  forgraph <- df %>% 
    rename(
      lci = rcap_lo,
      uci = rcap_hi,
      est = b
    ) %>% 
    mutate(
      period_ = cuat_since_switch*months_per_period,
      point_color = ifelse(p < .05, "black", "gray"),
      point_shape = ifelse(p < .05, 16, 1) # 16 is solid circle, 1 is hollow
    ) %>% 
    filter(period_ < 0) 
  
  # Replace period -1's NAs
  forgraph %<>% mutate(
    est = ifelse(is.na(est), 0, est),
    p = ifelse(is.na(p), 1, p),
    point_color = ifelse(is.na(point_color), "gray", point_color),
    point_shape = ifelse(is.na(point_shape), 1, point_shape)
  )
  
  if (is.null(y_breaks) & is.null(y_accuracy)) {
    yscale_ <- scale_y_continuous(expand = y_expand,
      limits = y_limits
    )
  } else if (!is.null(y_breaks) & is.null(y_accuracy)) {
    yscale_ <- scale_y_continuous(expand = y_expand,
      limits = y_limits, breaks = y_breaks
    )    
  } else if (!is.null(y_breaks) & !is.null(y_accuracy)) {
      yscale_ <- scale_y_continuous(expand = y_expand, 
        limits = y_limits, breaks = y_breaks,
        labels = scales::number_format(accuracy = y_accuracy)
      ) 
  } else if (is.null(y_breaks) & !is.null(y_accuracy)) {
      yscale_ <- scale_y_continuous(expand = y_expand, 
        limits = y_limits, 
        labels = scales::number_format(accuracy = y_accuracy)
      )    
  }
  title_ <- ggtitle(title)
  
  thegraph <- forgraph %>% 
    ggplot(aes(x = period_)) + 
      geom_hline(yintercept = 0) + 
      add_lines + # manual axis at time 0 if not pre-
      geom_point(data = forgraph %>% filter(point_shape==1 & point_color == "gray"), 
        aes(y = est), size = point_size, stroke = point_stroke, shape = 1, color = "gray40") + 
      geom_point(data = forgraph %>% filter(point_shape==16 & point_color == "gray"), 
        aes(y = est), size = point_size, stroke = point_stroke, shape = 16, color = "gray40") +      
      geom_point(data = forgraph %>% filter(point_shape==16 & point_color == "black"), 
        aes(y = est), size = point_size, stroke = point_stroke, shape = 16, color = "black") +   
      geom_errorbar(data = forgraph %>% filter(point_color == "black"),
        aes(ymin = lci, ymax = uci), width = error_width, size = error_size, color = "black") + 
      geom_errorbar(data = forgraph %>% filter(point_color == "gray"),
        aes(ymin = lci, ymax = uci), width = error_width, size = error_size, color = "gray40") + 
      yscale_ +
      scale_x_continuous(expand = x_expand, 
        limits = c(min_period - 0.1*months_per_period, max_period + 0.1*months_per_period),
        breaks = seq(min_period, max_period, by = months_per_period*label_by)) +
      title_ +
      labs(x = xtitle, y = ytitle) +
      theme_classic() + my_theme
  plot(thegraph)
  ggsave(here::here("graphs", str_c(outcome, "_pre", ".", filetype)),
    width = width, height = height
  )
}

# Savings
my_theme <- set_theme(16, y_title_size = NA,
  y_text_color = "black", # for panel graph,
  x_title_color = "white",
  x_title_margin = "t = 10"
)
graph_pre_trends(net_savings_ind_0, 
  outcome = "net_savings_ind_0",
  title = "Stock of savings (pesos)",
  y_limits = c(-100, 100),
  xtitle = "Months relative to switch to cards"
)

# Log savings
my_theme <- set_theme(size = 16, y_title_size = NA,
  y_text_color = "black",
  x_title_color = "black",
  x_title_margin = "t = 10"
)
graph_pre_trends(ln_net_savings_ind_0, 
  outcome = "ln_net_savings_ind_0",
  title = "Log stock of savings",
  y_limits = c(-0.6, 0.6),
  y_breaks = seq(-0.6, 0.6, by = 0.2),
  y_accuracy = 0.1,
  xtitle = "Months relative to switch to cards"
)

# Number of withdrawals
my_theme <- set_theme(size = 16, y_title_size = NA,
  y_text_color = "black",
  x_title_color = "white",
  x_title_margin = "t = 10"
)
graph_pre_trends(N_withdrawals, 
  outcome = "N_withdrawals",
  title = "Number of withdrawals",
  y_limits = c(-0.2, 0.2),
  xtitle = "Months relative to switch to cards"
)
