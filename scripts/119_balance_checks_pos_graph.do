** GRAPH AVERAGE BALANCE CHECKS RELATIVE TO POS/ATM TRANSACTION
**  Sean Higgins

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 119_balance_checks_pos_graph
cap log close
set linesize 200
log using "$logs/`project'`sample'_`time'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

************
** LOCALS **
************
graph_options, graph_margin(margin(small)) plot_margin(margin(sides))

local day_window = 7 // how many days around POS transaction
local outcome "n_day_bc"

foreach trans_type in POS { // add ATM for relative to ATM transaction
	foreach mm in means { // add event for event study results in addition to means

		**********
		** DATA **
		**********
		local graphname `outcome'_`trans_type'_`mm'`sample'
		use "$proc/`graphname'.dta", clear // coefficients from event study

		***********
		** GRAPH **
		***********
		#delimit ;
		graph twoway 
			(scatter beta k if p<0.05,           `estimate_options_95') 
			(scatter beta k if p>=0.05 & p<0.10, `estimate_options_90') 
			(scatter beta k if p>=0.10,          `estimate_options_0' ) 
			(rcap rcap_hi rcap_lo k if p<0.05,           `rcap_options_95')
			(rcap rcap_hi rcap_lo k if p>=0.05 & p<0.10, `rcap_options_90')
			(rcap rcap_hi rcap_lo k if p>=0.10,          `rcap_options_0' )
			, 
			title("Number of balance checks per day", `title_options')
			ylabel(, `ylabel_options') 
			yline(0, `manual_axis')
			xtitle("Days relative to `trans_type' transaction", `xtitle_options')
			xlabel(-`day_window'/`day_window', `xlabel_options') 
			xscale(range(-`day_window' `day_window') noline) /* because manual axis at 0 with yline above) */
			xline(0, `T_line_options') /* at 0 here because same day as transaction */
			`plotregion' `graphregion'
			legend(off) 
			name(`graphname', replace)
		;
		#delimit cr

		graph export "$graphs/`graphname'_`time'.pdf", replace
	}
}
	
*************
** WRAP UP **
*************
log close
exit


