** GENERATE GRAPHS OF WITHDRAWAL AND DEPOSIT DISTRIBUTIONS; EVENT STUDY FOR WITHDRAWALS
**  Pierre Bachas and Sean Higgins
**  Created 15April2016

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 107_eventstudy_graph
cap log close
set linesize 200
log using "$logs/`project'`sample'_`time'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

************
** LOCALS **
************
#delimit ;
local depvars
	N_withdrawals
	net_savings_ind_0_w5
;
local balance_check_vars
	sum_bc 
	sum_bc_pos_time 
	sum_bc_pos_time_wd 
	sum_bc_not_before_POS	
;

#delimit cr

**********
** DATA **
**********
// Graphs for withdrawals and savings
foreach depvar of local depvars {
	use "$proc/`depvar'`sample'.dta", clear

	// LOCALS FOR GRAPH
	if strpos("`depvar'", "withdrawals") local _format %2.1f
	else local _format %1.0f // based on magnitudes
	graph_options, labsize(large) ///
		ylabel_format(format(`_format')) ///
		plot_margin(margin(sides)) ///
		graph_margin(margin(top_bottom))
		
	summ cuat_since_switch, meanonly
	local min_xaxis = r(min)
	local max_xaxis = r(max)

	list, clean noobs

	set scheme s1color 
	#delimit ;
	graph twoway 
		(scatter b cuat_since_switch if p<0.05,  `estimate_options_95') 
		(scatter b cuat_since_switch if p>=0.05, `estimate_options_0' ) 
		(rcap rcap_hi rcap_lo cuat_since_switch if p<0.05,  `rcap_options_95')
		(rcap rcap_hi rcap_lo cuat_since_switch if p>=0.05, `rcap_options_0' )
		, 
		ylabel(, `ylabel_options') 
		yline(0, `manual_axis')
		xtitle("Four-month periods relative to switch to cards", `xtitle_options')
		xlabel(`min_xaxis'(1)`max_xaxis', `xlabel_options') 
		xscale(range(`min_xaxis' `max_xaxis'))
		xline(-0.5, `T_line_options')
		xscale(noline) /* because manual axis at 0 with yline above) */
		`plotregion' `graphregion'
		legend(off) 
		name(`depvar', replace)
	;
	#delimit cr	

	graph export "$graphs/`depvar'_event`sample'_`time'.pdf", replace 
}

// Graphs for balance checks
graph_options, labsize(large) ///
	ylabel_format(format(%2.1f)) ///
	x_labgap(labgap(3)) y_labgap(labgap(1)) ///
	plot_margin(margin(sides)) ///
	graph_margin(margin(top_bottom))

foreach depvar of local balance_check_vars {
	use "$proc/`depvar'`sample'.dta"
	
	#delimit ;
	graph twoway 
		(scatter b cuat if p<0.05,           `estimate_options_95') 
		(scatter b cuat if p>=0.05 & p<0.10, `estimate_options_90') 
		(scatter b cuat if p>=0.10,          `estimate_options_0' ) 
		(rcap rcap_hi rcap_lo cuat if p<0.05,           `rcap_options_95')
		(rcap rcap_hi rcap_lo cuat if p>=0.05 & p<0.10, `rcap_options_90')
		(rcap rcap_hi rcap_lo cuat if p>=0.10,          `rcap_options_0' )
		,
		ylabel(0(0.5)1.0, `ylabel_options') 
		yline(0, `manual_axis')
		yscale(range(0 1.25))
		ytitle("")
		xtitle("Four-month periods relative to switch to cards", `xtitle_options')
		xscale(range(-0.5 5) noline) /* noline because manual axis at 0 with yline above */
		xlabel(0(1)5, `xlabel_options') 
		xline(-0.5, `T_line_options') 
		legend(off)
		`graphregion' `plotregion'
		name(`depvar', replace)				
	;
	#delimit cr	

	graph export "$graphs/`depvar'_event`sample'_`time'.pdf", replace
}

*************
** WRAP UP **
*************
log close
exit
