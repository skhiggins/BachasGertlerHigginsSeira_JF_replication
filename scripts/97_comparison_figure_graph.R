## CREATE THE FINAL GRAPH COMPARING EFFECT SIZES FROM OUR STUDY TO OTHERS

## Created by Sean Higgins, Feb 2017

##############
## PACKAGES ##
##############
library(tidyverse) 
library(metafor) # for forest() command to make forest plot
library(colorspace) # for black and white version
library(here)

##########
## DATA ##
##########
rates <- read_csv(here::here("proc", "savings_rates.csv")) %>% as.data.frame()
	# savings rates, standard errors, confidence intervals
	# and metadata
	# from comparison_figure.do
	
###########
## GRAPH ##
###########
eps <- 1 # 1 to create .eps of graph
jpg <- 0
c.lo <- -0.02
c.hi <- 0.08

# Sort it
rates <- arrange(rates, -longer_term, -b)

# Prep to hack arrows onto clipped confidence intervals
#  (note code needs to be revised slightly if any confidence intervals
#   get clipped on one but not both sides)
rates <- mutate(rates, group = nrow(rates) - c(1:nrow(rates)) + 1) 
	# group is a variable going in descending order (corresponds to y-axis)
rates$n <- c(1:nrow(rates))
	# for some reason this wasn't working with mutate; did it the old-fashioned way
clipped <- rates[which(rates$lo < c.lo | rates$hi > c.hi),]

rates <- rates %>% 
	mutate(color = ifelse(lo < c.lo | hi > c.hi, "white", color))

for (color in c(0, 1)) { # color and black and white versions
	if (color == 0) {
	  color_vector <- desaturate(rates$color)
	  suffix <- "_bw"
	} else {
	  color_vector <- rates$color
	  suffix <- ""
	}
  
  if (eps==1) {
    setEPS() # to save the graph as an .eps
    postscript(here::here("graphs", str_c("comparison_figure", suffix, ".eps")), 
      width = 16, height = 8.233333
    )
  } 
  if (jpg==1) { 
    jpeg(file=here::here("graphs", str_c("comparison_figure", suffix, ".jpg")),
      width = 1600, height = 823
    ) 
  }
    
  # Forest plot
  par(font=1)
  longer_start_row  <- 1
  longer_end_row    <- sum(rates$longer_term)
  shorter_start_row <- longer_end_row + 3
  shorter_end_row   <- shorter_start_row + sum((rates$longer_term==0)) - 1
  forest(
  	rates$b, # observed effect sizes
  	ci.lb = rates$lo, # lower bound confidence interval
  	ci.ub = rates$hi, # upper bound confidence interval
  	annotate = FALSE, # try changing to false
  	clim = c(c.lo,c.hi), efac = c(1,2,1),
  	ylim = c(1,22),
  	xlim = c(c.lo - 0.13, c.hi + 0.005),
  	at = c(-.02,0,.02,.04,.06,.08),
  	alim = c(c.lo,c.hi),
  	xlab = "Stock of Savings as Proportion of Annual Income",
  	slab = NA,
  	ilab = as.data.frame(select(rates, AuthorYear, intervention, country, months)),
  	ilab.xpos = c(c.lo - 0.13, c.lo - 0.077, c.lo - 0.047, c.lo - 0.002),
  	ilab.pos = c(4,4,4,2), 
  	pch = rates$pch, psize = 1, col = color_vector,
  	lwd = 1,
  	cex = 1.2,
  	digits = 2, 
  	# separate into two panels by length of study 
  	# (http://www.metafor-project.org/doku.php/plots:forest_plot_with_subgroups)
  	rows = c(longer_start_row:longer_end_row,shorter_start_row:shorter_end_row)
  )
  
  # Arrows on clipped confidence interval 
  smspace <- 0
  arrowlen <- 0.075
  arrowypos <- clipped$n + 2 # manual patch for now (needed this when splitting into panels)
  arrows(clipped$b, arrowypos, # x, y start
  	rep(c.lo - smspace,times=nrow(clipped)), arrowypos, # x, y end
  	length = arrowlen, col = clipped$color, lwd = 1)
  arrows(clipped$b, arrowypos, # x, y start
  	rep(c.hi + smspace,times=nrow(clipped)), arrowypos, # x, y end
  	length = arrowlen, col = clipped$color, lwd = 1)
  points(clipped$b, arrowypos, # point location
  	pch = clipped$pch, col = clipped$color, cex = 1.2)
  
  
  # Add column headers to figure
  # par(font=2) # bold
  vertspace <- 4.5
  text(c.lo - 0.13,  vertspace + nrow(rates), "Study", pos=4, cex = 1.2)
  text(c.lo - 0.077,  vertspace + nrow(rates), "Intervention", pos=4, cex = 1.2)
  text(c.lo - 0.047,  vertspace + nrow(rates), "Country", pos=4, cex = 1.2)
  text(c.lo - 0.002, vertspace + nrow(rates), "Months", pos=2, cex = 1.2)
  text(0.025, vertspace + nrow(rates), "Effect Size", cex = 1.2)
  
  # Panel titles 
  # (http://www.metafor-project.org/doku.php/plots:forest_plot_with_subgroups)
  # par(font=3) # italic
  text(c.lo - 0.13/2, shorter_end_row + 1.125, "Panel A. Studies with Approximately One-Year Duration", cex = 1.2)
  text(c.lo - 0.13/2, longer_end_row + 1.125, "Panel B. Studies with Longer Duration", cex = 1.2)
  
  # Extra formatting lines requested by copyeditor
  segments(x0 = c.lo - 0.13, y0 = vertspace + nrow(rates) + 0.75, x1 = c.hi + 0.005) # top line
  segments(x0 = c.lo - 0.13, y0 = shorter_end_row + 0.625, x1 = c.lo - 0.002) # below Panel A
  segments(x0 = c.lo - 0.13, y0 = longer_end_row + 2, x1 = c.lo - 0.002) # above Panel B
  segments(x0 = c.lo - 0.13, y0 = longer_end_row + 0.625, x1 = c.lo - 0.002) # below Panel B
  
  par(xpd = NA) # xpd = NA allows line outside plot area: https://stackoverflow.com/questions/12496684/how-to-draw-a-line-or-add-a-text-outside-of-the-plot-area-in-r
  segments(x0 = c.lo - 0.13, y0 = -3, x1 = c.hi + 0.005) # bottom line

  # Save .eps or .png file
  if (eps==1 | jpg==1) { dev.off() }
  
}
