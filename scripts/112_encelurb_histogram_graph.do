** ENCELURB HISTOGRAM OF CARD RECEIPT
** Sean Higgins
** Created Jul  8 2015 as cleaned up version

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 112_encelurb_histogram_graph
cap log close
set linesize 200
log using "$logs/`project'_`time'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

*******************
** PRELIMINARIES **
*******************
if c(maxvar) < 32767 set maxvar 32767
if c(matsize) < 5000 set matsize 5000
include "$scripts/encelurb_dataprep_preliminary.doh" // !include!

************
** LOCALS **
************
local startyear = 2007

**********
** DATA **
**********
use "$proc/encel_forreg_bycategory.dta", clear // !data!

gen year_switch = real(substr(string(bimswitch),1,4))
gen bim_of_year_switch = real(substr(string(bimswitch),5,1))

#delimit ;
bimestrify , startyear(`startyear')
	bim(bim_of_year_switch) year(year_switch) 
	gen(bim_switch_count) 
;
#delimit cr
replace bim_switch_count = 32 if bim_switch_count > 32  // top code 

/* Manual histogram because Stata's histograms suck */
keep if year==2009  // one obs per HH in panel 
gen byte freq = 1 
collapse (sum) freq, by(bim_switch_count) 

#delimit ;
graph twoway bar freq bim_switch_count if bim_switch_count > 12,
	color(gray)
	xlabel(
		13 "Jan 2009" 
		19 "Jan 2010" 
		25 "Jan 2011" 
		31 "Jan 2012", 
		valuelabels nogrid notick labgap(*2)
	) 
	xtitle("Date received cards", margin(top))
	ylabel(, notick nogrid angle(horizontal))
	ytitle("Frequency", margin(right))
	xline(19, lcolor(gray) lpattern(dash)) /* survey */
	graphregion(margin(l+2 r+4) fcolor(white) lstyle(none) lcolor(white))
	plotregion(margin(none) fcolor(white) lstyle(none) lcolor(white)) 
;
#delimit cr

graph export "$graphs/hist_encel.eps", replace

*************
** WRAP UP **
*************
log close
exit
