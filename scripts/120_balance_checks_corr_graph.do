** BALANCE CHECKS CORRELATION WITH SAVINGS
**  Pierre Bachas and Sean Higgins

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 120_balance_checks_corr_graph
cap log close
local sample $sample 
set linesize 200
log using "$logs/`project'_`time'`sample'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

************
** LOCALS **
************
#delimit ;
local graph_list
	sum_bc
	sum_bc_pos_time
	sum_bc_pos_time_wd
	sum_bc_not_before_POS
;
#delimit cr

// Cutoff for definition of saving
local x 150

local alpha = 0.05

// Start and end of event study graph
local lowcuat 0
local hicuat  4
local cols = `hicuat' - `lowcuat' + 1 // 1 col per coefficient; 1 row per permutation

graph_options, labsize(large) ///
	x_labgap(labgap(2)) ///
	plot_margin(margin(t+10)) ///
	graph_margin(margin(top_bottom))

**********
** DATA **
**********
use "$proc/balance_checks_forreg`sample'.dta", clear

// Merge in savings
merge 1:1 integranteid cuat_since_switch using "$proc/netsavings_forreg`sample'.dta" 

keep if _merge == 3	
drop _merge 
  
// Restrict to those who save at some point after receiving card (otherwise have no variation in dependent variable)
sort integranteid `timevar', stable
uniquevals integranteid, count sorted
by integranteid : keep if net_savings_ind_0[_N] > `x' 
uniquevals integranteid, count sorted
	// i.e. if saving in last period observed for that integranteid
		
foreach var of varlist sum_bc* {
	tab `var'
	
	// Top code balance checks
	replace `var' = 5 if `var' >= 5 & !missing(`var')
	
	// Must be integers (some were not due to prorating in first period)
	replace `var' = round(`var')
}

// Summary statistics for paper:
count // Unique "bimester_redefined - ID" level observations 
	
foreach var of varlist sum_bc* {
	total `var'
}

*****************
** REGRESSIONS **
*****************
local depvar net_savings_ind_0_w5
foreach var of varlist sum_bc* {
	matrix `var' = J(6, 6, .)
	matrix colnames `var' = "checks" "b" "se" "p" "rcap_hi" "rcap_lo"
	xtreg `depvar' ib0.`var', fe vce(cluster branch_clave_loc)
	
	local rr = 0
	forval i = 0/5 { // cuat_since_switch
		local ++rr
		matrix `var'[`rr', 1] = `i'
		matrix `var'[`rr', 2] = _b[`i'.`var']
		matrix `var'[`rr', 3] = _se[`i'.`var']
		local teststat = abs(_b[`i'.`var']/_se[`i'.`var'])
		local pvalue = 2*ttail(e(df_r), `teststat')
		matrix `var'[`rr', 4] = `pvalue'
		// Confidence interval
		matrix `var'[`rr', 5] = _b[`i'.`var'] + ///
			invttail(e(df_r), `=`alpha'/2')*_se[`i'.`var']
		matrix `var'[`rr', 6] = _b[`i'.`var'] - ///
			invttail(e(df_r), `=`alpha'/2')*_se[`i'.`var']
	}
	
	**********
	** SAVE **
	**********
	preserve
	clear
	svmat `var', names(col)
	save "$proc/`var'_corr`sample'.dta", replace
	restore
	
}

***********
** GRAPH **
***********
foreach var of local graph_list {
	use "$proc/`var'_corr`sample'.dta", clear
	
	// Control whether display axis
	if ("`var'"=="sum_bc") | ("`var'"=="sum_bc_pos_time_wd") { 
		local _ylabel	ylabel(-500(100)100, `ylabel_options') 
		local _ytitle ytitle("Savings relative to 0 checks", `ytitle_options')
		local _noyline ""
	}
	else {
		local _ylabel ylabel(-500(100)100, `ylabel_options_invis')
		local _ytitle ytitle("")
		local _noyline noline
	}

	// GRAPH
	#delimit ; 
	twoway
		(scatter b checks if p < 0.05, `estimate_options_95') 
		(scatter b checks if p >= 0.05,  `estimate_options_0') 
		(rcap rcap_lo rcap_hi checks if p < 0.05, `rcap_options_95') 
		(rcap rcap_lo rcap_hi checks if p >= 0.05, `rcap_options_0') , 
		yscale(range(-520 100) `_noyline') xscale(noline)
		`_ylabel'
		`_ytitle'
		xlabel(0(1)5, `xlabel_options') 
		xtitle("Number of Balance Checks", `xtitle_options')
		yline(0, `manual_axis')
		`plotregion' `graphregion'
		legend(off) 
	;
	#delimit cr

	graph export "$graphs/`var'_corr_`time'`sample'.eps", replace

}
	
*************
** WRAP UP **
*************
log close
exit
