** BALANCE CHECKS OVER TIME RELATIVE TO CARD RECEIPT
**  Pierre Bachas and Sean Higgins

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 83_balance_checks_event
cap log close
local sample $sample 
set linesize 200
log using "$logs/`project'_`time'`sample'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

************
** LOCALS **
************
// Randomization inference
local randinf = 1
local N_perm = 2000 
	// "I find no appreciable change in rejection rates beyond 2,000 draws"--Young (2019)
local increment = 100 // how many permutations per do file run in the manual parallelization
#delimit ;
local randinf_vars 
	sum_bc 
	sum_bc_pos_time 
	sum_bc_pos_time_wd 
	sum_bc_not_before_POS
;
#delimit cr

local alpha = 0.05

// Start and end of event study graph
local lowcuat 0
local hicuat  4
local cols = `hicuat' - `lowcuat' + 1 // 1 col per coefficient; 1 row per permutation

***************
** FUNCTIONS **
***************
cap program drop count_obs_in_reg
program define count_obs_in_reg, rclass
	count if e(sample) 
	di "Number of accounts by time in reg: " r(N)
	return scalar N = r(N)
	uniquevals integranteid if e(sample)
	di "Number of accounts in reg: " r(unique)
	return scalar N_accounts = r(unique)
	uniquevals branch_clave_loc if e(sample)
	di "Number of localities in reg: " r(unique)
	return scalar N_localities = r(unique)
end

**********
** DATA **
**********
use "$proc/balance_checks_forreg`sample'.dta", clear

***************************************************
// Balance checks regression with account FE
***************************************************

foreach depvar of varlist sum_bc* {
	mydi "`depvar'"

	matrix `depvar' = J(`cols', 6, .) // 0-5 cuatrimesters 
	matrix colnames `depvar' = "cuat" "b" "se" "p" "rcap_hi" "rcap_lo" 
	
	matrix N_`depvar' = J(1, 3, .)
	matrix colnames N_`depvar' = "N" "N_accounts" "N_localities"	

	matrix `depvar'_teststat = J(1, `cols', .)

	xtreg `depvar' ib(last).cuat_since_switch, fe vce(cluster branch_clave_loc)
	
	// save N
	count_obs_in_reg
	matrix N_`depvar'[1, 1] = r(N)
	matrix N_`depvar'[1, 2] = r(N_accounts)
	matrix N_`depvar'[1, 3] = r(N_localities)
	
	local i = 0
	forval cuat = `lowcuat'/`hicuat' { // cuat_since_switch
		local ++i
		matrix `depvar'[`i', 1] = `cuat'
		matrix `depvar'[`i', 2] = _b[`cuat'.cuat_since_switch]
		matrix `depvar'[`i', 3] = _se[`cuat'.cuat_since_switch]
		local teststat = abs(_b[`cuat'.cuat_since_switch]/_se[`cuat'.cuat_since_switch])
		matrix `depvar'_teststat[1, `i'] = `teststat'
		local pvalue = 2*ttail(e(df_r), `teststat')
		matrix `depvar'[`i', 4] = `pvalue'
		// Confidence interval
		matrix `depvar'[`i', 5] = _b[`cuat'.cuat_since_switch] + ///
			invttail(e(df_r), `=`alpha'/2')*_se[`cuat'.cuat_since_switch]
		matrix `depvar'[`i', 6] = _b[`cuat'.cuat_since_switch] - ///
			invttail(e(df_r), `=`alpha'/2')*_se[`cuat'.cuat_since_switch]
	}
	
	**********
	** SAVE **
	**********
	// Save results as data set
	preserve
	
	clear
	svmat `depvar', names(col)
	save "$proc/`depvar'`sample'.dta", replace
	
	clear
	svmat N_`depvar', names(col)
	save "$proc/`depvar'_N`sample'.dta", replace
		
	restore
	
	// Randomization inference
	if `randinf' {
		// Check if `depvar' is one of the elements of `randinf_vars'
		local _continue 1
		foreach x of local randinf_vars {
			if "`depvar'"=="`x'" local _continue 0
		}
		if `_continue' continue
		
		local mat_name `depvar'_ri

		// Read all the permuted test statistics into data
		preserve
		clear
		local start_perm = 1
		while `start_perm' < `N_perm' {
			local end_perm = `start_perm' + `increment' - 1
			
			if `start_perm'==1 use "$proc/`mat_name'_`start_perm'_`end_perm'`sample'.dta"
			else append using "$proc/`mat_name'_`start_perm'_`end_perm'`sample'.dta"
			
			local start_perm = `end_perm' + 1
		}

		// Save permuted test statistics as a data set
		save "$proc/`mat_name'_permuted_t`sample'.dta", replace
		
		clear 
		svmat `depvar'_teststat, names(col)
		save "$proc/`depvar'_teststat`sample'.dta", replace
		
		restore
	}

}
	
*************
** WRAP UP **
*************
log close
exit
