** WITHDRAWALS AT ATMs OVER TIME
**  Pierre Bachas and Sean Higgins

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 105_ATM_use_graph
cap log close
local sample $sample 
set linesize 200
log using "$logs/`project'_`time'`sample'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

************
** LOCALS **
************
// For graphs:
graph_options, labsize(large) ///
	ylabel_format(format(%2.1f)) ///
	x_labgap(labgap(3)) y_labgap(labgap(1)) ///
	plot_margin(margin(sides)) ///
	graph_margin(margin(top_bottom))

**********
** DATA **
**********
foreach outcome in used_ATM { // add used_POS to see POS transaction behavior
	use "$proc/`outcome'`sample'.dta", clear // ATM_use_regs.do
	foreach var of varlist se rcap_hi rcap_lo {
		replace `var' = . if cuat < 0
	}
	replace p = 1 if cuat < 0

	#delimit ;	
		
	graph twoway 
		(scatter b cuat if p< 0.05, `estimate_options_95')
		(scatter b cuat if p>=0.05, `estimate_options_0' )
		(rcap rcap_lo rcap_hi cuat if p< 0.05, `rcap_options_95')
		(rcap rcap_lo rcap_hi cuat if p>=0.05, `rcap_options_0')	
		, 
		ylabel(0(.2)1, `ylabel_options') 
		xlabel(-9(1)5, `xlabel_options') 
		xline(-0.5 , `T_line_options') 
		xtitle("Four-month periods relative to switch to cards", `xtitle_options')
		ytitle("", `ytitle_options')
		name(`outcome', replace)
		`graphregion' `plotregion'
		legend(off) 
	;

	#delimit cr

	foreach ftype in eps {
		graph export "$graphs/`outcome'_event`sample'_`time'.`ftype'", replace
	}
}

*************
** WRAP UP **
*************
log close
exit
