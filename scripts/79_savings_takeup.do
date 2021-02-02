** DECOMPOSITION OF SAVINGS EFFECT
**  Sean Higgins

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 79_savings_takeup
cap log close
local sample $sample
set linesize 200
log using "$logs/`project'_`time'`sample'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

************
** LOCALS **
************
// Control center
local depvar "net_savings_ind_0_w5" 
local include_controls_list 0 1 

// Savings cut-offs
local xlist 150 // 100 150 200 250 300 500 // testing robustness

local lowcuat -9
local hicuat   5
local periods = `hicuat' - `lowcuat' + 1

// Baseline variables that will be merged in
#delimit ;
local stats_list 
	N_client_deposits
	N_withdrawals 
	/* Exclude the baseline variables mechanically related to depvar
			since baseline is still included as a time period in this regression
	proportion_wd      
	sum_Op_deposit     
	net_savings_ind_0 
	*/
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
use "$proc/netsavings_forreg`sample'.dta", replace

// Create the necessary local macros
qui summ css if t==1 
local lo = r(min) 
local hi = r(max) 

summ cuat_since_switch, meanonly
local min = abs(r(min))
di r(min)
local min_1 = `min' - 1
local min_2 = `min' - 2

local cutoff 150 
	
** keep if cuatrimester > 1	
sort integranteid cuatrimester, stable

// The shifting creates noise in balance,
//  which is why we define saving as having above some cut-off in 
//  3 consecutive periods (if the 2nd and 3rd consecutive periods exist)
sort integranteid cuatrimester, stable
by integranteid (cuatrimester) : gen byte takeup = (`depvar' > `cutoff') & ///
	`depvar'[_n+1] > `cutoff' & ///
	`depvar'[_n+2] > `cutoff'  

tab t, mi
qui count if t==1
di "`r(N)' account-period observations with t==1"
qui uniquevals integranteid_num if t==1
di "`r(unique)' unique accounts with t==1"

// Calculate the means and standard errors for a table

// Matrices for results
matrix results = J(`periods', 6, .)
matrix colnames results = "cuat" "b" "se" "p" "rcap_lo" "rcap_hi"
matrix results_N = J(1, 4, .)
matrix colnames results_N = "N" "N_accounts" "N_branches" "N_localities"

reg takeup ibn.css if t==1 & cuat_since_switch >= -9 & cuat_since_switch <= 5, noconstant ///
	vce(cluster branch_clave_loc)
	
count if e(sample)
matrix results_N[1, 1] = r(N)
uniquevals integranteid if e(sample)
matrix results_N[1, 2] = r(unique)
uniquevals sucadm if e(sample)
matrix results_N[1, 3] = r(unique)
uniquevals branch_clave_loc if e(sample)
matrix results_N[1, 4] = r(unique)
	
local row = 0
forval rr = `lowcuat'/`hicuat' {
	local ++row
	local _ss = `rr' + `min'
	matrix results[`row', 1] = `rr'
	matrix results[`row', 2] = _b[`_ss'.css]
	matrix results[`row', 3] = _se[`_ss'.css]
	local teststat = abs(_b[`_ss'.css]/_se[`_ss'.css])
	local pvalue = 2*ttail(e(df_r), `teststat')
	matrix results[`row', 4] = `pvalue'
	
	// Confidence interval
	matrix results[`row', 5] = _b[`_ss'.css] - invttail(e(df_r), 0.025)*_se[`_ss'.css]
	matrix results[`row', 6] = _b[`_ss'.css] + invttail(e(df_r), 0.025)*_se[`_ss'.css]		
}

**********
** SAVE **
**********
// Save results as data set
preserve
clear
svmat results, names(col)
save "$proc/proportion_saving`sample'.dta", replace

clear
svmat results_N, names(col)
save "$proc/proportion_saving_N`sample'.dta", replace

restore

// Since starting to save
sort integranteid cuatrimester, stable
by integranteid : egen cuat_takeup = min(cuatrimester) if takeup==1
by integranteid : replace cuat_takeup = cuat_takeup[_N]
gen cuat_since_takeup = cuatrimester - cuat_takeup
summ cuat_since_switch , meanonly
local min = abs(r(min))
gen cst = cuat_since_takeup + `min' // dt factor var restrictions
tab cst 

// label the cst var for graphs
summ cst, meanonly
forval cc=`r(min)'/`r(max)' {
	local cst_label_local `cst_label_local' `cc' "`=`cc'-`min''"
}
label define cst_label `cst_label_local'
label values cst cst_label
		
tab cst, nolabel
tab cst
tab cuat_since_takeup 

xi i.t*i.cst, noomit
de _I*
		
foreach var of varlist _ItXcst* {
	recode `var' (. = 0)
}
		
qui summ cst if t==1 
local lo = r(min) 
local hi = r(max)

local col = 0
foreach depvar of varlist net_savings_ind_0* { 

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

		#delimit ;
		xtreg `depvar' i.cuatrimester `controls'
			/* precard omitted */
			_ItXcst_1_`min'-_ItXcst_1_`hi'   /* post-card */
			, fe vce(cluster branch_clave_loc)
		;
		#delimit cr

		local col = 0
		matrix results_N = J(1, 4, .)
		matrix colnames results_N = "N" "N_accounts" "N_branches" "N_localities"
		di as result e(N) _s as text "account-period observations"
		local ++col
		matrix results_N[1, `col'] = e(N)
		di as result e(N_g) _s as text "accounts"
		local ++col
		matrix results_N[1, `col'] = e(N_g)
		qui uniquevals sucadm if e(sample)                         
		di as result r(unique) _s as text "branches"  
		local ++col
		matrix results_N[1, `col'] = r(unique)                   
		qui uniquevals branch_clave_loc if e(sample)               
		di as result r(unique) _s as text "localities"  
		local ++col
		matrix results_N[1, `col'] = r(unique)         

		local df = e(df_r)
		
		// Matrix of results
		matrix results = J(`=`hicuat'+1', 4, .) // + 1 for 0 row
			// Columns:
			//  1) relative period k, for k = a to b, a < 0 < b
			//  2) beta of D_i x I(t = tau_i + k) term
			//  3) s.e.
			//  4) p-value
		local row = 0
		forval rr = 0/`hicuat' {
			local ++row
			local _ss = `rr' + `min'
			matrix results[`row',1] = `rr'
			matrix results[`row',2] = _b[_ItXcst_1_`_ss']
			matrix results[`row',3] = _se[_ItXcst_1_`_ss']
			matrix results[`row',4] = 2*ttail(`df', ///
				abs(_b[_ItXcst_1_`_ss']/_se[_ItXcst_1_`_ss']) ///
			)
		}
			
		matlist results
			
		**********
		** SAVE **
		**********
		preserve
		clear
		svmat results
		rename results1 cuat_since_takeup // cuatrimestres since switch
		rename results2 b
		rename results3 se
		rename results4 p

		tempvar rcap_hi rcap_lo
		gen rcap_hi = b + invttail(`df',0.025)*se
		gen rcap_lo = b - invttail(`df',0.025)*se
		
		local _depvar = subinstr("`depvar'", "net_savings_ind_0", "savings", .)
		// because strings were getting too long for Stata locals

		save "$proc/`_depvar'_st`_controls'`sample'.dta", replace
			// _st for since takeup

		clear 
		svmat results_N, names(col)
		save "$proc/`_depvar'_st`_controls'_N`sample'.dta", replace

		restore
		
	}
}

*************
** WRAP UP **
*************
log close
exit
