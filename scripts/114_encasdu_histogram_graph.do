** ENCASDU HISTOGRAM OF MONTHS WITH CARD
**  created September 13 2016

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 114_encasdu_histogram_graph
cap log close
set linesize 200
log using "$logs/`project'_`time'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

**********
** DATA **
**********
use "$proc/encasdu_forreg.dta", clear

// Manual histogram because Stata's histograms suck
summ days_card, meanonly
gen rel_dateswitch = r(max) - days_card 
gen rel_dateswitch_bin = floor(rel_dateswitch/10) + 1 // bin width = 10

gen byte freq = 1
collapse (sum) freq, by(rel_dateswitch_bin)
summ rel_dateswitch_bin
#delimit ;
graph twoway bar freq rel_dateswitch_bin,
	color(gray)
	xscale(range(0 `=2*`r(max)''))
	xlabel(0.5 "Jan 2009"
		`=`r(max)'+0.5' "Jan 2010"
		`=2*`r(max)'+0.5' "Jan 2011"
		, 
		notick nogrid angle(horizontal) labgap(*2)) 
	xtitle("Date received cards", margin(top))
	ylabel(, notick nogrid angle(horizontal))
	ytitle("Frequency", margin(right))
	graphregion(margin(l+2 r+4) fcolor(white) lstyle(none) lcolor(white))
	plotregion(margin(none) fcolor(white) lstyle(none) lcolor(white)) 
	xline(`=1.75*`r(max)'+0.5', lcolor(gray) lpattern(dash))
;
#delimit cr

graph export "$graphs/hist_encasdu.eps", replace

*************
** WRAP UP **
*************
log close
exit
