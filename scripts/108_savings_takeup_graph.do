** GRAPH DECOMPOSITION OF SAVINGS EFFECT
**  Sean Higgins

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 108_savings_takeup_graph
cap log close
local sample $sample 
set linesize 200
log using "$logs/`project'_`time'`sample'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

**********
** DATA **
**********
// PROPORTION SAVING OVER TIME
use "$proc/proportion_saving`sample'.dta", clear

set scheme s1color
graph_options, ///
	labsize(large) ///
	x_labgap(labgap(2)) ///
	ylabel_format(format(%2.1f)) ///
	plot_margin(margin(none)) ///
	graph_margin(margin(medium))
	
summ cuat, meanonly
local min_xaxis = r(min)
local max_xaxis = r(max)

#delimit ;
graph twoway 
	(line b cuat, lwidth(medthick) lcolor(black))
		if cuat>=`min_xaxis' & cuat<=`max_xaxis',  
	ylabel(0(.2)1, `ylabel_options') 
	ytitle("")
	yscale(range(0 1))
	xtitle("Four-month periods relative to switch to cards", `xtitle_options')
	xlabel(`min_xaxis'(1)`max_xaxis', `xlabel_options') 
	xscale(range(`min_xaxis' `max_xaxis'))
	xline(-0.5, `T_line_options')
	`plotregion' `graphregion'
	legend(off) 
	name(cum_takeup, replace)
;
#delimit cr

graph export "$graphs/proportion_saving`sample'_`time'.eps", replace

// SAVINGS RATE CONDITIONAL ON SAVING
use "$proc/savings_st`sample'.dta", clear // _st is since takeup

local min_xaxis = 0
local max_xaxis = 2

set scheme s1color
graph_options, ///
	labsize(large) ///
	x_labgap(labgap(2)) ///
	plot_margin(margin(sides)) ///
	graph_margin(margin(medium))
			
#delimit ;
graph twoway 
	(scatter b cuat_since_takeup if p<0.05 &
		cuat_since_takeup<=`max_xaxis', `estimate_options_95') 
	(scatter b cuat_since_takeup if p>=0.05 &
		cuat_since_takeup<=`max_xaxis', `estimate_options_0' ) 
	(rcap rcap_hi rcap_lo cuat_since_takeup if p<0.05 &
		cuat_since_takeup<=`max_xaxis', `rcap_options_95')
	(rcap rcap_hi rcap_lo cuat_since_takeup if p>=0.05 &
		cuat_since_takeup<=`max_xaxis', `rcap_options_0' )
	, 
	ylabel(0(200)800, `ylabel_options') 
	yline(0, `manual_axis')
	xtitle("Four-month periods relative to {bf:starting to save}", `xtitle_options')
	xlabel(`min_xaxis'(1)`max_xaxis', `xlabel_options') 
	xscale(range(`min_xaxis' `max_xaxis'))
	xline(-0.5, `T_line_options')
	xscale(noline) /* because manual axis at 0 with yline above) */
	`plotregion' `graphregion'
	legend(off) 
	name(saving_event_`x', replace)
;
#delimit cr

graph export "$graphs/saving_since_takeup`sample'_`time'.eps", replace

*************
** WRAP UP **
*************
log close 
exit
