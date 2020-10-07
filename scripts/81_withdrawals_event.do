** EVENT STUDY FOR WITHDRAWALS
**  Pierre Bachas and Sean Higgins
**  Created 15April2016

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 81_withdrawals_event
cap log close
set linesize 200
log using "$logs/`project'`sample'_`time'.log", text replace
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
local randinf_vars N_withdrawals // not all vars because too slow
local seed 84215923 // from random.org

// Controls
local include_controls_list 0 1

// Start and end of event study graph
local lowcuat -9
local hicuat   5

// Baseline variables that will be merged in
#delimit ;
local stats_list 
	N_client_deposits
	/* Exclude the baseline variables mechanically related to depvar
			since baseline is still included as a time period in this regression
	N_withdrawals
	*/
	proportion_wd 
	sum_Op_deposit
	net_savings_ind_0
	years_w_account
;
#delimit cr

foreach var of local stats_list {
	local mi_stats_list `mi_stats_list' mi_`var'_bl
	local stats_list_bl `stats_list_bl' `var'_bl
}

**********
** DATA **
**********
use "$proc/account_withdrawals_forreg`sample'.dta", clear

qui summ css if t==1 
local lo = r(min) 
local hi = r(max) 

summ cuat_since_switch , meanonly
local min = abs(r(min))
local min_1 = `min' - 1
local min_2 = `min' - 2

foreach depvar of varlist N_withdrawals* {
	// Not the baseline variables
	if strpos("`depvar'", "_bl") continue
	
	foreach include_controls of local include_controls_list { // with and without baseline x time controls
		// Only do the baseline controls x time FE for _w5 because it's slow
		if !strpos("`depvar'", "_w5") & `include_controls' continue
		
		if !(`include_controls') {
			local controls ""
			local _controls ""
		}
		else {
			local controls c.(`stats_list_bl')#i.cuatrimester i.(`mi_stats_list')#i.cuatrimester
			local _controls "_blxtime"
		} 

		// REGRESSION
		#delimit ;
		xtreg `depvar' i.cuatrimester `controls'
			_ItXcss_1_`lo'-_ItXcss_1_`min_2' /* pre-card */
			_ItXcss_1_`min'-_ItXcss_1_`hi'   /* post-card */
			, fe vce(cluster branch_clave_loc)
		;
		#delimit cr
		mydi "OMITTED PERIOD: `min_1'", s(4) starchar("^")
		
		local col = 0
		matrix N_results = J(1, 4, .)
		matrix colnames N_results = "N" "N_accounts" "N_branches" "N_localities"
		di as result e(N) _s as text "account-period observations"
		local ++col
		matrix N_results[1, `col'] = e(N)
		qui uniquevals integranteid if e(sample)
		di as result r(unique) _s as text "accounts"
		local ++col
		matrix N_results[1, `col'] = r(unique) 
		qui uniquevals sucadm if e(sample)     	
		di as result r(unique) _s as text "branches"   
		local ++col
		matrix N_results[1, `col'] = r(unique)
		qui uniquevals branch_clave_loc if e(sample)               
		di as result r(unique) _s as text "localities"  
		local ++col
		matrix N_results[1, `col'] = r(unique)

		tab bimester if e(sample)
		tab bim_switch if e(sample) & tag
		tab css if e(sample) & t==1, nol
			// this shows the omitted _ItXcss_1_0 and _ItXcss_1_1 are because
			//  no treatment are that many periods pre-switch (only control are)
			
		local df = e(df_r)
		
		// Matrix of results
		local rows = `hicuat' - `lowcuat' + 1
		display `rows'
		matrix results = J(`rows', 4, .)
			// Columns:
			//  1) relative period k, for k = a to b, a < 0 < b
			//  2) beta of D_i x I(t = tau_i + k) term
			//  3) s.e.
			//  4) p-value
		matrix teststat = J(1, `rows', .) // for randomization inference
		local row = 0
		forval rr = `lowcuat'/`hicuat' {
			local ++row
			local _ss = `rr' + `min'
			matrix results[`row', 1] = `rr'
			if `_ss'==`min_1' { // omitted period
				matrix results[`row', 2] = 0
				continue 
			} 
			matrix results[`row', 2] = _b[_ItXcss_1_`_ss']
			matrix results[`row', 3] = _se[_ItXcss_1_`_ss']
			local teststat = abs(_b[_ItXcss_1_`_ss']/_se[_ItXcss_1_`_ss'])
			matrix teststat[1, `row'] = `teststat'
			local pvalue = 2*ttail(`df', `teststat')
			matrix results[`row', 4] = `pvalue'
		}
		
		matlist results

		**********
		** SAVE **
		**********
		// Save results as data set
		preserve
		clear
		svmat results
		rename results1 cuat_since_switch // cuatrimestres since switch
		rename results2 b
		rename results3 se
		rename results4 p
		
		// Additional variables
		gen rcap_hi = b + invttail(`df', 0.025)*se
		gen rcap_lo = b - invttail(`df', 0.025)*se

		save "$proc/`depvar'`_controls'`sample'.dta", replace
		
		clear
		svmat N_results, names(col)
		save "$proc/`depvar'`_controls'_N`sample'.dta", replace
		
		restore
				
		// Randomization inference
		if `randinf' {
			// Check if `depvar' is one of the elements of `randinf_vars'
			local _continue 1
			foreach x of local randinf_vars {
				if "`depvar'"=="`x'" local _continue 0
			}
			if `_continue' continue
			
			// Skip robustness check with hh char x time because randomization inference too slow
			if `include_controls' continue // not doing randomization inference for this
			
			local mat_name `depvar'_ri`_controls'
				
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
			svmat teststat, names(col)
			save "$proc/`depvar'`_controls'_teststat`sample'.dta", replace
			
			restore
		}
	}
}

*************
** WRAP UP **
*************
log close
exit
		