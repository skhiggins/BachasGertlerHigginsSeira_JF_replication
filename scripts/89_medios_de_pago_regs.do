** REGRESSIONS FROM PAYMENT METHODS SURVEY
**  Written by Pierre Bachas and Sean Higgins
**  created December 2014

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 89_medios_de_pago_regs
cap log close
set linesize 200
log using "$logs/`project'_`time'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

************
** LOCALS **
************
** Control center
local randinf = 1 // to do randomization inference
// Number of permutations
local N_perm = 2000
if c(matsize) < `N_perm' set matsize `N_perm'
	// "I find no appreciable change in rejection rates beyond 2,000 draws"--Young (2019)
local seed 20191208 // needed for replicable randomization inference
set seed `seed'

// Outcomes
#delimit ;
local outcomes 
	fees_check
	fees_withdraw
	check_nowithdrawal
	hard_use_ATM 
	help_ATM 
	knows_PIN
;
#delimit cr
local rows = wordcount("`outcomes'")

// Vars for balance table 
** N household members // t201
** N children // not in survey
** Age of hh head // t301
** HH head male // t302
** HH head marries // t303
** Educ level of head // t311a (nivel), t311b (grado)
** Occ per room // not in survey
** Access to health insurance // not in survey
** Asset index // not in survey
** Income // not in survey
#delimit ;
local balance_list
	t201
	t301
	male
	married
	escolaridad
;

// Vars for third set of regressions, with individual level controls + locality controls ;
local baseline_controls 
	log_wage
	log_precio
	log_pos
	log_branch_number
	log_atm_number
	log_cards_all
	net_savings_ind_0
	log_net_savings_ind_0
	N_withdrawals 
;
local has_data /* control for missing values of locality-level controls */
	data_POS
	data_bansefi
	data_cnbv
	data_cpix
	data_enoe 			
;	
#delimit cr 	

**********
** DATA **
**********
use "$proc/medios_de_pago.dta", clear // medios_de_pago_dataprep.do

*****************
** REGRESSIONS **
*****************
matrix results = J(`=`rows'*3', 5, .) 	// 3 rows for each outcome (less than median =0, =1, and row for diff) 
	// Initial column: control mean
	// Next 3 columns: the 3 specifications
	// Final column: N
	// 
matrix pvalues = J(`=`rows'*3', 5, .) // for Latex table stars
	// pvalues will have asymptotic cluster-robust pvalue;
	// results will have the randomization inference pvalues

// Control means
local row = 0
foreach depvar of varlist `outcomes' {
	regress `depvar' [pw=PONDEF] if card_less==1, cluster(localidad)
	local ++row
	matrix results[`row', 1] = _b[_cons]
	local ++row
	matrix results[`row', 1] = _se[_cons]
	local ++row // an extra row for p-value in other columns
}

** 3 sets of regressions:
**  1) no controls
**  2) baseline individual-level controls from survey data (same vars as in Table 3) 
**  3) baseline individual-level survey controls (Table 3 vars) AND 
**      locality/municipality-level controls from other data sets (Figure 3 vars)

forval i=1/3 { // which of the 3 sets above
	local row = 0
	
	// Controls
	if      `i' == 1 local controls ""
	else if `i' == 2 local controls `balance_list'
	else if `i' == 3 local controls `balance_list' `baseline_controls' `has_data'
	local j = `i' + 1 // first column is control mean
	
	foreach depvar of varlist `outcomes' {
		regress `depvar' ib1.card_less `controls' [pw=PONDEF], cluster(localidad) // mean and se for card_less==1
		local ++row
		matrix results[`row', `j'] = _b[0.card_less] // mean for those who have had card < 6 mo
		local teststat = abs(_b[0.card_less]/_se[0.card_less])
		local pvalue = 2*ttail(e(df_r), `teststat')	
		matrix pvalues[`row', `j'] = `pvalue'
		if results[`row', 5] != . assert e(N) == results[`row', 5]
			// same N regardless of controls
		matrix results[`row', 5] = e(N)
		local ++row
		matrix results[`row', `j'] = _se[0.card_less]
		local df = e(df_r)
		
		local ++row
		if `randinf' { // Randomization inference p-value
			randcmd ((card_less) reg `depvar' card_less  `controls' [pw=PONDEF], cluster(localidad)), ///
				treatvars(card_less) reps(`N_perm') seed(`seed')	
			matrix randinf_pvalues = e(RCoef)
			// Keep the randomization-t p-value 
			//  ("Although in principle all randomization test statistics are
			//		equally valid, in practice I find the randomization-t to be superior
			//		to the -c" from Young (2019))
			matrix results[`row',`j'] = randinf_pvalues[1,6] 			
		}
		else { // If not doing randomization inference, use regular p-value
			matrix results[`row', `j'] = `pvalue'
		}
	}
}
matlist results
matlist pvalues

**********
** SAVE **
**********
preserve
clear
svmat results, names(col)
save "$proc/medios_de_pago_results.dta", replace

clear
svmat pvalues
save "$proc/medios_de_pago_pvalues.dta", replace

restore

*******************
** BALANCE TESTS **
*******************
local rows = wordcount("`balance_list'")*2
matrix results = J(`rows',3,.)

local row = 1
foreach var of local balance_list {
	mydi "`var'"
	summ `var', meanonly
	if r(min)<0 local highonly ""
	else local highonly "highonly"
	tempvar `var'_w
	_pctile `var', n(100)
	if r(r95)>0 ///	
		winsify `var', winsor(5) gen(``var'_w') `highonly'
	else ///
		gen ``var'_w' = `var'
	
	// Control group mean
	regress ``var'_w' [pw=PONDEF] if card_less==1, cluster(localidad)
	matrix results[`row',1] = _b[_cons]
	matrix results[`=`row'+1',1] = _se[_cons]

	// Difference
	reg ``var'_w' ib1.card_less [pw=PONDEF], cluster(localidad)
	matrix results[`row',2] = _b[0.card_less]
	matrix results[`=`row'+1',2] = _se[0.card_less]	
	local pvalue = 2*ttail(e(df_r), abs(_b[0.card_less]/_se[0.card_less]))
	matrix results[`row',3] = `pvalue'
	
	// Add randomization inference p-value
	if `randinf' {
		randcmd ((card_less) reg ``var'_w' card_less [pw=PONDEF], cluster(localidad)), ///
			treatvars(card_less) reps(`N_perm') seed(`seed')	
		matrix randinf_pvalues = e(RCoef)
		// Keep the randomization-t p-value 
		//  ("Although in principle all randomization test statistics are
		//		equally valid, in practice I find the randomization-t to be superior
		//		to the -c" from Young (2019))
		matrix results[`=`row'+1',3] = randinf_pvalues[1,6] 		
	}
	else { // If not doing randomization inference, use regular p-value
		matrix results[`=`row'+1',3] = `pvalue'
	}
	local row = `row' + 2
}

matlist results

// hack to get stars right
matrix pvalues = J(`rows',3,.)
matrix pvalues[1,3] = results[1...,3]
matlist results
matlist pvalues


**********
** SAVE **
**********
preserve
clear
svmat results, names(col)
save "$proc/medios_de_pago_balance_results.dta", replace

clear
svmat pvalues
save "$proc/medios_de_pago_balance_pvalues.dta", replace

restore

*************
** WRAP UP **
*************
log close
exit
