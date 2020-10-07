# FUNCTIONS

# my tabulator package
#  (regular remotes::install_github() installation didn't work on server
#   because it requires R 3.4.2 and server has 3.3.x)
tabulator_functions <- list.files(
  here::here("scripts", "tabulator"), 
  pattern = ".R$", 
  full.names = TRUE
)
for (function_ in tabulator_functions) {
  source(function_)
}

# Set theme for graphs
set_theme <- function(
    size = 14, 
    title_size = size,
    title_hjust = 0.5,
    y_title_size = size,
    x_title_size = size,
    y_title_margin = NULL,
    x_title_margin = NULL,
    y_text_size = size,
    x_text_size = size,
    y_text_color = "black",
    x_text_color = "black",
    y_title_color = "black", 
    x_title_color = "black",
    legend_text_size = size,
    plot_title_position = NULL,
    axis_title_y_blank = FALSE, # to fully left-align
    aspect_ratio = NULL
  ) {
  # Size
  size_ <- str_c("size = ", size) # this argument always included

  if (is.na(y_title_size)) {
    y_title <- "element_blank()"
  } else {
    
    # y-title margin
    if (!is.null(y_title_margin)) y_title_margin_ <- str_c("margin = margin(", y_title_margin, ")")
    else y_title_margin_ <- ""
    

    # y-title color
    if (!is.null(y_title_color)) y_title_color_ <- str_c("color = '", y_title_color, "'")
    else y_title_color_ <- ""

    # create y_title
    y_title <- str_c("element_text(", size_, ",", y_title_margin_, y_title_color_, ")")
    
  }
  if (is.na(x_title_size)) {
    x_title <- "element_blank()"
  }
  else {
    # x-title margin
    if (!is.null(x_title_margin)) x_title_margin_ <- str_c("margin = margin(", x_title_margin, ")")
    else x_title_margin_ <- ""
        
    # x-title color
    if (!is.null(x_title_color)) x_title_color_ <- str_c("color = '", x_title_color, "'")
    else x_title_color_ <- ""
    
    # create x_title
    x_title <- str_c("element_text(", size_, ",", x_title_margin_, ",", x_title_color_, ")")
  }
  
  if (axis_title_y_blank) {
    y_title <- "element_blank()" # overwrite what it was written as above
  }
    
  theme(
    plot.title = element_text(size = title_size, hjust = title_hjust),
    plot.title.position = plot_title_position,
    axis.title.y = eval(parse(text = y_title)),
    axis.title.x = eval(parse(text = x_title)),
    axis.ticks = element_blank(),
    axis.text.y = element_text(size = y_text_size, color = y_text_color),
    axis.text.x = element_text(size = x_text_size, color = x_text_color),
    axis.line = element_blank(), # manual axes
    legend.key = element_rect(fill = "white"),
    legend.text = element_text(size = legend_text_size),
    legend.title = element_text(size = legend_text_size),
    aspect.ratio = aspect_ratio
  )
}

# Comprehensive key creator in case missing interem periods
create_key <- function(dt, period1, period2 = NULL, n_periods, newvars = NULL) {
    # Note period has to be in YYYY... format, eg 200901 for months, 20091 for quarter, etc.
  min_period <- min(dt[[period1]], na.rm = TRUE)
  max_period <- max(dt[[period1]], na.rm = TRUE)
  if (!is.null(period2)) {
    min_period2 <- min(dt[[period2]], na.rm = TRUE)
    max_period2 <- max(dt[[period2]], na.rm = TRUE)
    min_period <- min(min_period, min_period2)
    max_period <- max(max_period, max_period2)
  }
  min_year <- str_sub(min_period, 1, 4) %>% as.integer()
  max_year <- str_sub(max_period, 1, 4) %>% as.integer()
  min_subperiod <- str_sub(min_period, 5, nchar(min_period)) %>% as.integer()
  max_subperiod <- str_sub(max_period, 5, nchar(max_period)) %>% as.integer()
  
  rows <- (max_year - min_year + 1)*n_periods
  the_key <- matrix(nrow = rows, ncol = 2)
  r <- 0
  for (year in seq(min_year, max_year, by = 1)) {
    for (pd in seq(1, n_periods, by = 1)) { # starts at 1 even if min_sem_sem > 1
      r <- r + 1
      the_key[r, 1] <- str_c(year %>% as.character(), pd %>% as.character())
      the_key[r, 2] <- r 
    }
  }
  the_key %<>% as.data.table()
  the_key[, V2 := as.numeric(V2)]
  if (!is.null(newvars)) {
    names(the_key) <- newvars
  } else {
    names(the_key) <- c("period", "period_key")
  }
  
  the_key
}

merge_key <- function(dt, period1, period2 = NULL, n_periods, newvars = NULL) {
  the_key <- dt %>% create_key(period1, period2, n_periods)
  dt %<>% merge(the_key, by.x = period1, by.y = "period", all.x = TRUE)
  if (!is.null(newvars)) {
    dt[, (newvars[[1]]) := period_key]
    dt[, period_key := NULL]
  }
  dt %<>% merge(the_key, by.x = period2, by.y = "period", all.x = TRUE)
  if (!is.null(newvars)) {
    dt[, (newvars[[2]]) := period_key]
    dt[, period_key := NULL]
  }
  dt
}

# Create lag variable or delta variable in a data.table
create_lag <- function(dt, var, newvar, index, delta = FALSE, lag = 1) {
  temp_p <- dt %>% plm::pdata.frame(index = index)
  if (delta == TRUE) {
    dt[, (newvar) := temp_p[[var]] - plm::lag(temp_p[[var]])]
  } else {
    dt[, (newvar) := plm::lag(temp_p[[var]], lag = lag)]
  }
}


time_stamp <- function() {
  datestamp <- Sys.time() %>% 
      str_sub(1, 10) %>% 
      str_replace_all("-", "")
  timestamp <- Sys.time() %>% 
    str_sub(12, 19) %>% 
    str_replace_all(":", "")
  str_c("_", datestamp, "_", timestamp)
}

no_special <- function(x) {
  x %>% 
    str_replace_all(" ", "") %>% 
    str_replace_all("/", "") %>% 
    str_replace_all("\\.", "") %>% # escape it
    str_replace_all("-", "") %>% 
    str_replace_all("á", "a") %>% 
    str_replace_all("é", "e") %>% 
    str_replace_all("í", "i") %>%
    str_replace_all("ó", "o") %>% 
    str_replace_all("ú", "u") %>% 
    str_replace_all("ñ", "n")  
    # can add more here as needed
}

# Preliminary regression function (since felm object is way too large)
felm_coef <- function(...) {
  my_felm <- lfe::felm(...)
  coefs <- summary(my_felm)$coefficients %>% tbl_df
  names(coefs) <- c("est", "se", "t", "p")
  # include the row.names as a column in the tibble:
  coefs %<>% mutate(period = 
    row.names(summary(my_felm)$coefficients)) %>% 
    select(period, everything()) # reorder
  my_coef <- list(coefs, my_felm$N)
  names(my_coef) <- c("coef", "N")
  my_coef
}
safe_felm_coef <- safely(felm_coef)

# Means over time (for comparison)
#  Assumes treatment variable is named treat...can generalize later
means_over_time <- function(df, outcomes, control = TRUE) {
  if (control == TRUE) {
    print("T means")
    df[treat == 1, lapply(.SD, mean), 
      .SDcols = outcomes, by = year_bim] %>% print_all()
    print("T and C means")
    df[treat == 1 | treat == 0, lapply(.SD, mean), 
      .SDcols = outcomes, by = year_bim] %>% print_all()
    print("C means")
    df[treat == 0, lapply(.SD, mean), 
      .SDcols = outcomes, by = year_bim] %>% print_all()
    print("Overall C mean for benchmark")
    df[treat == 0, lapply(.SD, mean), 
      .SDcols = outcomes] %>% print_all()
  } else {
    print("treat==1 means")
    df[treat == 1, lapply(.SD, mean), 
      .SDcols = outcomes, by = year_bim] %>% print_all()
    print("k = -1 means")
    df[treat == 1 & fac_to_num(bim_since_switch) == -1, lapply(.SD, mean), 
      .SDcols = outcomes, by = year_bim] %>% print_all()    
  }
}

# Graph event studies
graph_event_study <- function(results, n_clust, alpha = 0.05, 
  lo_graph = -Inf, hi_graph = Inf,
  lo_limit = -Inf, hi_limit = Inf,
  y_breaks = NULL, y_expand = c(0.01, 0.01), y_accuracy = NULL, x_expand = c(0, 0),
  theme = theme_classic(), gg_title = "", label_by = 6,
  months_per_period = 2, error_width = 0.2, error_size = 0.3,
  point_size = 2, point_stroke = 0.5,
  xtitle = "Months since card shock", ytitle = "", pre = FALSE) {
  
  results$coef %<>% mutate(
    period_ = period %>% str_extract("-?[0-9]*$") %>% as.integer(),
    uci = est + se * qt(1 - alpha/2, df = n_clust - 1),
    lci = est - se * qt(1 - alpha/2, df = n_clust - 1),
    point_color = ifelse(p < .05, "black", "gray"),
    point_shape = ifelse(p < .1, 16, 1) # 16 is solid circle, 1 is hollow
  )
  # Add in period -1 (the omitted)
  results$coef %<>% bind_rows(data.frame(
    period_ = -1, est = 0, se = NA, p = 1, uci = NA, lci = NA, 
    point_color = "gray", point_shape = 1
  )) %>% 
    mutate(period_ = months_per_period*period_) %>%  # display as months rather than bim
    arrange(period_)
  min_period <- results$coef %$% min(period_)
  max_period <- results$coef %$% max(period_)
  if (!identical(theme, theme_classic())) {
    my_theme = theme_classic() + theme
  }
  if (is.null(y_breaks)) {
    if (!is.null(y_accuracy)) {
      yscale_ <- scale_y_continuous(expand = y_expand, 
        limits = c(lo_limit, hi_limit), 
        labels = scales::number_format(accuracy = y_accuracy)
      )
    } else {
      yscale_ <- scale_y_continuous(expand = y_expand, 
        limits = c(lo_limit, hi_limit)
      )      
    }
  } else {
    if (!is.null(y_accuracy)) {    
      yscale_ <- scale_y_continuous(expand = y_expand, 
        limits = c(lo_limit, hi_limit),
        labels = scales::number_format(accuracy = y_accuracy),
        breaks = y_breaks
      )   
    } else {
      yscale_ <- scale_y_continuous(expand = y_expand, 
        limits = c(lo_limit, hi_limit),
        breaks = y_breaks
      )         
    }
  }
  if (pre == TRUE) {
    add_lines <- NULL
    forgraph <- results$coef %>% filter(period_ >= lo_graph & period_ < 0)
    max_period <- 0 # overwrite
    # xtitle <- "" # overwrite
  } else {
    add_lines <- geom_vline(xintercept = -0.5) # manual axis at time 0
    forgraph <- results$coef %>% filter(period_ >= lo_graph & period_ <= hi_graph)
  }
  if (!is.null(gg_title)) {
    title_ <- ggtitle(gg_title)
  } else {
    title_ <- NULL
  }
  thegraph <- forgraph %>% 
    ggplot(aes(x = period_)) + 
      geom_hline(yintercept = 0) + 
      add_lines + 
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
      my_theme
  results$coef %>% print(n = Inf)
  thegraph # plot it
}

# Binned event study with my specific data sets
binned_event_study <- function(df, cut_off = NULL, bin_at, outcomes, 
    giro = 0, control = FALSE, y_cutoffs = NULL, y_breaks = NULL, months_per_period = 2, 
    period_since_switch = "bim_since_switch",
    i_unit = "localidad",
    t_unit = "year_bim",
    weight_by = NULL,
    fixed_effects = NULL,
    cluster = NULL,
    suffix = "", label_by = NA,
    width = 8, height = 5, titles = NULL, filetype = "eps", ...) {
  # Previously I put the sector as the title on the graph; now put "In levels" or "In logs"
  #  in order to put them side by side
  if (giro == 0) {
      giro_ <- ""
      #   title_ <- "All retailers"
  } else {
      giro_ <- str_c("_giro", giro)
      #   title_ <- get(str_c("title_", giro))
  }
  
  # Convert bim_since_switch to numeric so I can bin, then back to factor
  forreg <- df[, (period_since_switch) := lapply(.SD, function(x) as.numeric(as.character(x))), 
    .SDcols = period_since_switch]
    # used as.numeric(as.character()) rather than more efficient fac_to_num
    #  because mix of positives and negatives makes as.numeric(levels(x))[x] error
  if (control == FALSE) {
    forreg <- forreg[treat == 1] # treated; no pure control
    control_ <- ""
  } else {
    forreg <- forreg[treat == 1 | treat == 0]
    control_ <- "_control"
  }
  
  # Restrict time periods and bin
  forreg[, period_since_switch_copy := lapply(.SD, function(x) x), .SDcols = period_since_switch] # to keep a numeric without binning

  # Cut offs
  if (!is.null(cut_off)) {
    filter <- str_c(period_since_switch, " >= cut_off[[1]] & ", period_since_switch, " <= cut_off[[2]]")
    forreg <- forreg[eval(parse(text = filter))]
    cut_display <- str_c(" cut ", cut_off[[1]], "_", cut_off[[2]])
    cut_graphname <- str_c("_cut", abs(cut_off[[1]]), "_", abs(cut_off[[2]]))
  } else {
    cut_display <- ""
    cut_graphname <- ""
  }
  # Bins
  forreg[, 
    (period_since_switch) := lapply(.SD, function(x) ifelse( # binning at ends
      x < bin_at[[1]], bin_at[[1]], ifelse(
      x > bin_at[[2]], bin_at[[2]], x)
    ) %>%  
      # back to factor
      as.factor() %>% relevel(ref = "-1")
    ), .SDcols = (period_since_switch)
  ]
  
  # NULL stuff
  if (is.null(fixed_effects)) fixed_effects <- str_c(i_unit, " + ", t_unit)
  if (is.null(cluster)) cluster <- i_unit
  if (is.null(weight_by)) {
    weight_formula <- "weights = NULL"
  } else {
    weight_vector <- forreg[[weight_by]]
    weight_formula <- str_c("weights = weight_vector")
  }
  
  n_clust <- forreg[, .GRP, by = cluster][, .N]
  print("n_clust")
  print(n_clust)
  
  # RESULTS
  graphs <- vector("list", length(outcomes))
  for (i in seq_along(outcomes)) {
    outcome <- outcomes[[i]]
    
    print(outcome) # for debugging
    
    model_formula <- str_c(outcome, " ~ ", period_since_switch, " | ", 
      fixed_effects, # fixed effects
      " | 0 | ",             # no instruments
      cluster                # cluster
      )
    assign(outcome, safe_felm_coef(
      eval(parse(text = model_formula)), 
      data = forreg, 
      eval(parse(text = weight_formula))) %>% .$result)
    if (is.null(get(outcome))) next
    
    # Show how many per period
    print("by period")
    forreg[!is.na(outcome), .N, by = period_since_switch] %>% print()
  
    # Do a diff in diff as well
    # if (control == TRUE) { # otherwise diff-in-diff not identified
      forreg[, D_jt := (treat == 1)*(period_since_switch_copy >= 0)]
        # treat x post
      dd_formula <- str_c(outcome, " ~ D_jt | ", 
        fixed_effects, # fixed effects
        " | 0 | ",     # no instruments
        cluster        # cluster
      )
      assign(str_c("dd_", outcome), safe_felm_coef(
        eval(parse(text = dd_formula)), 
        data = forreg,
        eval(parse(text = weight_formula))
      ))
      get(str_c("dd_", outcome)) %>% print()
      bin_filter <- str_c()
      assign(str_c("dd_atbin_", outcome), safe_felm_coef( # stop at bin rather than cut
        eval(parse(text = dd_formula)), 
        data = forreg[
          period_since_switch_copy >= bin_at[[1]] & 
          period_since_switch_copy <= bin_at[[2]]
        ],
        eval(parse(text = weight_formula))
      ))
      get(str_c("dd_atbin_", outcome)) %>% print()
    # }
   
    print("---------------------")
    print(str_c(outcome, 
      cut_display, 
      " bin at ", bin_at[[1]], "_", bin_at[[2]], 
      giro_, control_, suffix
    ))
    print("---------------------")
    print("$coef")
    get(outcome) %>% .$coef %>% print(n = Inf)
    print("$N")
    get(outcome) %>% .$N %>% print()
    
    # if (control == TRUE) { # otherwise diff in diff not identified
      print("---------------------")
      print(str_c("dd_", outcome, 
        cut_display, " bin at ", bin_at[[1]], "_", bin_at[[2]], 
        giro_, control_, suffix
      ))   
      print("---------------------")
      print("$coef")
      get(str_c("dd_", outcome)) %>% .$result %>% .$coef %>% print(n = Inf) # result due to safely
      print("$N")
      get(str_c("dd_", outcome)) %>% .$result %>% .$N %>% print()
      
      print("---------------------")
      print(str_c("dd_atbin_", outcome, 
        cut_display, " bin at ", bin_at[[1]], "_", bin_at[[2]], 
        giro_, control_, suffix
      ))   
      print("---------------------")
      print("$coef")
      get(str_c("dd_atbin_", outcome)) %>% .$result %>% .$coef %>% print(n = Inf)
      print("$N")
      get(str_c("dd_atbin_", outcome)) %>% .$result %>% .$N %>% print()
    # }

    # GRAPH
    if (is.null(y_cutoffs)) {
      lo_y <- NA
      hi_y <- NA
    } else {
      if (is.list(y_cutoffs)) {
        lo_y <- y_cutoffs[[i]][[1]]
        hi_y <- y_cutoffs[[i]][[2]]
      } else {
        lo_y <- y_cutoffs[[1]]
        hi_y <- y_cutoffs[[2]]
      }
    }
    if (!is.null(y_breaks)) {
      if (is.list(y_breaks)) y_breaks_ <- y_breaks[[i]]
      else y_breaks_ <- y_breaks
    } else {
      y_breaks_ <- NULL
    }
    
    if (is.na(label_by)) {
      if (mod(bin_at[[1]], 6) == 0) {
        label_by <- 6
      } else if (mod(bin_at[[1]], 3) == 0) {
        label_by <- 3
      } else { # -8
        label_by <- 4
      }
    }
    if (is.list(titles)) {
      gg_title <- titles[[i]]
    } else {
      gg_title <- titles # could be NULL
    }
    graphs[[i]] <- get(outcome) %>% 
      graph_event_study(
        n_clust = n_clust, lo_graph = months_per_period*bin_at[[1]], hi_graph = months_per_period*bin_at[[2]], # 2* bc months rather than bim
        lo_limit = lo_y, hi_limit = hi_y, y_breaks = y_breaks_,
        months_per_period = months_per_period,
        theme = my_theme, label_by = label_by, gg_title = gg_title, ...
      )
    graphs[[i]] # plot
    ggsave(file.path("graphs", 
      str_c(outcome, 
        cut_graphname,
        "_bin", abs(bin_at[[1]]), "_", abs(bin_at[[2]]),
        giro_, control_, suffix, ".", filetype)), 
      width = width, height = height
    )
  } # end for outcome in outcomes loop
  return(graphs)
}

winsorize <- function(dt, outcome, newvar, by = NULL, w = 5, highonly = FALSE, na.rm = FALSE) {
  if (is.null(by)) {
    dt[, dummy := 1]
    by = "dummy"
  }
  dt[, winlevel_hi := quantile(eval(parse(text = outcome)), probs = 1 - w/100, na.rm = na.rm), by = by]
  dt[, winlevel_lo := quantile(eval(parse(text = outcome)), probs = w/100, na.rm = na.rm), by = by]
  if (highonly) {
    dt[, (newvar) := ifelse(eval(parse(text = outcome)) > winlevel_hi, winlevel_hi, 
      eval(parse(text = outcome))
    )]
  } else {
    dt[, (newvar) := ifelse(eval(parse(text = outcome)) > winlevel_hi, winlevel_hi, 
      ifelse(eval(parse(text = outcome)) < winlevel_lo, winlevel_lo, eval(parse(text = outcome))
    ))]    
  }
  winlevels <- dt %>% select_colnames("winlevel")
  dt[, (winlevels) := NULL]
  dt
}

# For factors that should have been numeric
fac_to_num <- function(x) { # see http://bit.ly/2x26lUU
  as.numeric(levels(x))[x] # faster than as.numeric(as.character(x))
}
fac_to_int <- function(x) { # see http://bit.ly/2x26lUU
  as.integer(levels(x))[x] # faster than as.integer(as.character(x))
}
check_convert <- function(x, FUN=fac_to_int) {
  if (class(x)=="factor") {
    FUN(x)
  }
  else {
    x
  }
}
# NAs to 0 (if NA, no added or dropped POS terminals that day)
na_to_0 <- function(x, reverse = FALSE) {
  if (reverse) {
    ifelse(x == 0, NA, x)
  } else {
    ifelse(is.na(x), 0, x)
  }
}
# Lowercase names
lowercase_names <- function(df) {
  require(stringr)
  require(purrr)
  names(df) <- map_chr(names(df), str_to_lower)
  df # return
}
select_colnames <- function(df, pattern, ...) {
  if (length(list(...)) > 0) pattern <- str_c(c(pattern, ...), collapse = "|")
  names(df)[names(df) %>% map_lgl(function(x) str_detect(x, pattern) %>% any())]
    # the any() is so that pattern can have multiple elements, 
    #  and it just looks for one of the elements
    # which means you can either specify as select_colnames(df, c("a", "b"))
    #  or because of the ..., as select_colnames(df, "a", "b")
}
select_elements <- function(x, pattern) {
  x[x %>% map_lgl(function(x) str_detect(x, pattern))]
}
select_cols <- function(df, string) {
  df %>% .[, which(purrr::map_lgl(names(.), stringr::str_detect, string))]
} # Added this because it works with both data.table and tibble, 
  #  whereas select(contains()) only works with tibble

# Print all rows of tibble/data.table/etc.
print_all <- function(x) {
  print(x, n = Inf)
}

# Read transposed csv (each row represents a variable)
read.transposed.xlsx <- function(file, sheetIndex = 1) { # http://bit.ly/2yeQkIB
  require(xlsx)
  df <- read.xlsx(file, sheetIndex = sheetIndex , header = FALSE)
  dft <- as.data.frame(t(df[-1]), stringsAsFactors = FALSE) 
  names(dft) <- df[,1] 
  # dft <- as.data.frame(lapply(dft,type.convert))
  return(dft)            
}

# Read dbf as tibble, lowercase var names
read_dbf <- function(x, lower = TRUE, ...) {
  require(foreign)
  require(dplyr)
  require(stringr)
  a <- read.dbf(x, ...) %>% as_tibble()
  if (lower) {
    names(a) <- str_to_lower(names(a))
  }
  a
}

# FUNCTIONS FOR GETTING COORDINATES FROM GOOGLE MAPS API
#  Using code from https://www.r-bloggers.com/using-google-maps-api-and-r/ as starting point
#  Modified to use Mexico's zip codes rather than address and to work with updates to
#   the Google Maps geocode API
url <- function(cp, country, key, return.call = "json") { # cp is codigo postal
  if (typeof(cp) != "character") cp <- as.character(cp)
  root <- "https://maps.googleapis.com/maps/api/geocode/"
  u <- str_c(root, return.call, "?components=postal_code:", cp, 
    "|country:", country, 
    "&key=", key)
  return(URLencode(u))
}

geoCode <- function(cp, country, key) {
  if (typeof(cp) != "character") cp <- as.character(cp)
  u <- url(cp, country = country, key = key)
  doc <- getURL(u)
  x <- fromJSON(doc, simplify = FALSE)
  x$postal_code <- cp # add zip code to results as an element of the list
  return(x) # note I revised the code to extract everything
    # then created a new function clean_geo_info to get the
    # useful info but still preserve an object with all the info
    # from the request
}

clean_geo_info <- function(x) {
  if (x$status=="OK") {
    cp <- x$postal_code
    lat <- x$results[[1]]$geometry$location$lat
    lng <- x$results[[1]]$geometry$location$lng
    location_type <- x$results[[1]]$geometry$location_type
    formatted_address <- x$results[[1]]$formatted_address
    name1 <- tryCatch(x$results[[1]]$address_components[[2]]$long_name, 
      error = function(e) return(NA_character_))
    name2 <- tryCatch(x$results[[1]]$address_components[[3]]$long_name, 
      error = function(e) return(NA_character_))
    state <- tryCatch(x$results[[1]]$address_components[[4]]$long_name, 
      error = function(e) return(NA_character_))
    place_id <- x$results[[1]]$place_id
    status <- x$status
  } else {
    cp <- x$postal_code
    lat <- NA_real_
    lng <- NA_real_
    location_type <- NA_character_
    formatted_address <- NA_character_
    name1 <- NA_character_
    name2 <- NA_character_
    state <- NA_character_
    place_id <- NA_character_
    status <- x$status
  }
  results <- tribble( # one row tibble (then map will make many rows,
    # one row per postal code)
    ~cp, ~lat, ~lon, ~location_type, 
    ~formatted_address, ~name1, ~name2, ~state, ~place_id, ~status,
    cp, lat, lng, location_type, 
    formatted_address, name1, name2, state, place_id, status
  )
}

# Format numbers
formatted <- function(x) format(x, nsmall = 2, big.mark = ",")
  # http://r4ds.had.co.nz/r-markdown.html

