## CREATE THE FINAL GRAPH COMPARING EFFECT SIZES FROM OUR STUDY TO OTHERS

## Created by Sean Higgins, Feb 2017

##############
## PACKAGES ##
##############
library(tidyverse) 
library(metafor) # for forest() command to make forest plot
library(here)

###############
## FUNCTIONS ##
###############
# John Loeser's Stata-esque replace function
replace_stata <- function(df, column, replacement, ...) {
	require(dplyr)
	lazycond <- lazyeval::lazy_dots(...)
	names(lazycond) <- "temp"
	evalcond <- df %>% mutate_(.dots = lazycond) %>%
		select(temp) %>% unlist
	var_col <- as.character(substitute(column))
	df[,var_col] <- ifelse(evalcond, replacement, df[,var_col])
	return(df)
}

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

if (eps==1) {
	setEPS() # to save the graph as an .eps
	postscript(here::here("graphs", "comparison_figure.eps"), 
		width = 16, height = 8.233333
	)
} 
if (jpg==1) { 
	jpeg(file=here::here("graphs", "comparison_figure.jpg"),
		width = 1600, height = 823
	) 
}

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
	# replace_stata(lo, 0, lo < c.lo) %>%
	# replace_stata(hi, 0, hi > c.hi)
	replace_stata(color, "white", lo < c.lo | hi > c.hi) 
	
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
	pch = rates$pch, psize = 1, col = rates$color,
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
par(font=3) # italic
text(c.lo - 0.13, shorter_end_row + 1, "Panel A: Studies with about 1 year duration", pos=4, cex = 1.2)
text(c.lo - 0.13, longer_end_row + 1, "Panel B: Studies with longer duration", pos=4, cex = 1.2)

# Save .eps or .png file
if (eps==1 | jpg==1) { dev.off() }
# add arrows to indicate the clipped confidence interval

