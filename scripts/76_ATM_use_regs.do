** WITHDRAWALS AT ATMs OVER TIME
**  Pierre Bachas and Sean Higgins

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 76_ATM_use_regs
cap log close
set linesize 200
log using "$logs/`project'_`time'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

************
** LOCALS **
************
local lowcuat -9
local hicuat   5
local periods = `hicuat' - `lowcuat' + 1

**********
** DATA **
**********
use "$proc/ATM_use`sample'.dta", clear

summ cuat_since_switch , meanonly
// Periods outside of graph
local min = abs(r(min))
local min_1 = `min' - 1 // omitted period
gen css = cuat_since_switch + `min' // dt factor var restrictions 

*** REGRESSION TO GET THE CONFIDENCE INTERVALS
foreach outcome_ in ATM POS {
	local outcome used_`outcome_' 
	local n_outcome n_`outcome_'
	local is_outcome is_`outcome_'
	
	// Matrices for results
	matrix `outcome' = J(`periods', 6, .)
	matrix colnames `outcome' = "cuat" "b" "se" "p" "rcap_lo" "rcap_hi"
	matrix `outcome'_N = J(1, 3, .)
	matrix colnames `outcome'_N = "N" "N_accounts" "N_localities"
	
	// Overall mean
	summ `outcome' if cuat_since_switch >= 0 & cuat_since_switch<=5 & !mi(css)
	
	// Number of transactions
	summ `n_outcome' if css >= 0 & !mi(css), d
	summ `n_outcome' if `outcome' == 1 & css >= 0 & !mi(css), d 

	// Averages period
	reg `outcome' ib`min_1'.css if t==1, vce(cluster branch_clave_loc)
	
	count if e(sample)
	matrix `outcome'_N[1, 1] = r(N)
	uniquevals integranteid if e(sample)
	matrix `outcome'_N[1, 2] = r(unique)
	uniquevals branch_clave_loc if e(sample)
	matrix `outcome'_N[1, 3] = r(unique)
	
	local row = 0
	forval rr = `lowcuat'/`hicuat' {
		local ++row
		local _ss = `rr' + `min'
		matrix `outcome'[`row', 1] = `rr'
		if `_ss'==`min_1' { // omitted period
			matrix `outcome'[`row', 2] = 0
			continue 
		} 
		matrix `outcome'[`row', 2] = _b[`_ss'.css]
		matrix `outcome'[`row', 3] = _se[`_ss'.css]
		local teststat = abs(_b[`_ss'.css]/_se[`_ss'.css])
		local pvalue = 2*ttail(e(df_r), `teststat')
		matrix `outcome'[`row', 4] = `pvalue'
		
		// Confidence interval
		matrix `outcome'[`row', 5] = _b[`_ss'.css] - invttail(e(df_r), 0.025)*_se[`_ss'.css]
		matrix `outcome'[`row', 6] = _b[`_ss'.css] + invttail(e(df_r), 0.025)*_se[`_ss'.css]		
	}
	
	**********
	** SAVE **
	**********
	// Save results as data set
	preserve
	clear
	svmat `outcome', names(col)
	save "$proc/`outcome'`sample'.dta", replace
	
	clear
	svmat `outcome'_N, names(col)
	save "$proc/`outcome'_N`sample'.dta", replace
	
	restore
}

*************
** WRAP UP **
*************
log close
exit
