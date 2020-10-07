// BASELINE SUMMARY STATS
//  Sean Higgins

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 109_account_summary_stats_table
cap log close
set linesize 200
log using "$logs/`project'`sample'_`time'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

// Variables
local transfer "sum_Op_deposit"
local depvar "net_savings_ind_0"  

#delimit ;
local stats_list 
	N_client_deposits
	N_withdrawals
	N_withdraw_1
	N_withdraw_2
	N_withdraw_3
	proportion_wd 
	`transfer'
	`depvar'
	years_w_account
;

local titles_list 
	`"
	"{Number of client deposits}"
	"{Number of withdrawals}"
	"{Made exactly 1 withdrawal}"
	"{Made exactly 2 withdrawals}"
	"{Made 3 or more withdrawals}"
	"{\% of transfer withdrawn}"
	"{Size of Oportunidades transfer (pesos)}"
	"{Net balance (pesos)}"
	"{Years with account}"
	"'
;

#delimit cr

use "$proc/bansefi_baseline`sample'.dta", clear
describe

local rows = wordcount("`stats_list'")
matrix results = J(`rows', 5, .)
local row = 0
foreach var of local stats_list {
	local ++row
	
	// Winsorize 
	_pctile `var'_bl if !missing(t), n(100)
	if r(r95)>0 ///
		winsify `var'_bl if !missing(t), winsor(5) replace
		
	summ `var'_bl, d
	matrix results[`row', 1] = r(mean)
	matrix results[`row', 2] = r(sd)
	matrix results[`row', 3] = r(p25)
	matrix results[`row', 4] = r(p50)
	matrix results[`row', 5] = r(p75)
}

matlist results

// Send to Latex
local u "$tables/account_summary_stats.tex"
forval i=1/`rows' {
	local title: word `i' of `titles_list'
	
	if `i'<=5 local f_ "%1.0f"
	else if `i'>5 & `i'<=6 local f_ "%4.0f"
	else local f_ "%6.2f"
	
	if `i'==1 local _append "replace"
	else local _append "append"
	latexify results[`i', 1...] using `u', ///
		format(%6.2f %6.2f `f_' `f_' `f_') `_append' ///
		title(`title')
}

*************
** WRAP UP **
*************
log close 
exit


