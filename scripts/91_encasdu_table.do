** ENCASDU - MAPO (Panel & MAS) & EDUCACION 2010
** !created December 12 2014
**  Test whether those who have had card for less time have less trust in bank; less knowledge

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 91_encasdu_table
cap log close
set linesize 200
log using "$logs/`project'_`time'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

************
** LOCALS **
************
// Control center
local tables  = 1
local write   = 1
local balance_test = 1
local randinf = 1 // to do randomization inference
// Number of permutations
** if "`sample'" == "_sample1" local N_perm = 100 // laptop
** else local N_perm = 2000 // server
local N_perm 2000
	// "I find no appreciable change in rejection rates beyond 2,000 draws"--Young (2019)
local seed 61084137 // from random.org

local days_per_month = 365/12

// Outcomes
#delimit ;
local outcomes 
	donttrust 
	knowledge 
	ineligible
;
local rows = wordcount("`outcomes'");
local outcome_titles
	`"
	"Lack of trust"
	"Lack of knowledge" 
	"Fear of program ineligibility"
	"'
;

// Vars for balance table 
** N household members 
** N children 
** Age of hh head 
** HH head male 
** HH head marries 
** Educ level of head 
** Occ per room 
** Access to health insurance 
** Asset index 
** Income
#delimit ;
local balance_list 
	n_member
	edad_jefe
	titular_male
	titular_married
	escolaridad_jefe
	n_kid
	oc_por_cuarto
	p_seguro
	z_assetindex
	totinc
;
local balance_titles
	`"
	"\# Household members"
	"Age"
	"Male"
	"Married"
	"Education level"
	"\# Children"
	"Occupants per room"
	"Health insurance"
	"Asset index"
	"Income"
	"'
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

// For graphs:
local lang "en" // "en" for English; "es" for Spanish
if "`lang'"=="es" spanishaccents // my user-written ado file; saves locals with accents, e.g. `_e_' is é

if "`lang'"=="en" { // English
	local card "Debit card"
	local _time  "median time"
	local title "Does not save in Bansefi account due to"
	local xtitle "Reason for not saving in Bansefi account"
	local ytitle "Proportion"
	local _knowledge "Lack of knowledge"
	local _ineligible "Fear of ineligibility"
	local _trust "Lack of trust"
}
else { // es // Spanish
	local card "Tarjeta de d`_e_'bito"
	local _time  "1 a`_n_'o"
	local title "No ahorra en cuenta Bansefi por"
	local xtitle "Raz`_o_'n por la cual no ahorra en su cuenta Bansefi"
	local ytitle "Proporci`_o_'n"
	local _knowledge `" "Falta de" "conocimiento" "'
	local _ineligible `" "Miedo de" "darse de baja" "'
	local _trust `" "Falta de" "confianza" "'
	local _lang "_es"
}

**********
** DATA **
**********
use "$proc/encasdu_forreg.dta", clear

************
** TABLES **
************
// Add a control for if they're missing the control variable 
//  to keep same number of observations across regressions
count
foreach var of varlist `balance_list' {
	count if mi(`var')
	gen has_`var' = !missing(`var')
	replace `var' = 0 if has_`var' == 0
	local has_balance `has_balance' has_`var'
}

// Aditional analysis
// !USED IN PAPER! (footnote): comparing time with card in 2 groups
forval i=0/1 {
	qui summ days_card if card_less==`i'
	foreach x in min mean {
		scalar _`x'_months`i' = r(`x')/`days_per_month'
	}
}
di "Minimum for those with less than median time with card: "
di _min_months1
di "Difference in average time with card:"
di _mean_months0 - _mean_months1

if `tables' {	
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
		regress `depvar' if card_less==1, cluster(localidad)
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
		else if `i' == 2 local controls `balance_list' `has_balance'
		else if `i' == 3 local controls `balance_list' `has_balance' `baseline_controls' `has_data'
		local j = `i' + 1 // first column is control mean
		
		foreach depvar of varlist `outcomes' {
			regress `depvar' ib1.card_less `controls', cluster(localidad) // mean and se for card_less==1
			local ++row
			local b_hat = _b[0.card_less] // reused below in randomization inference
			matrix results[`row', `j'] = `b_hat'
			local teststat = abs(_b[0.card_less]/_se[0.card_less])
			local pvalue = 2*ttail(e(df_r), `teststat')	
			matrix pvalues[`row', `j'] = `pvalue'
			if results[`row', 5] != . assert e(N) == results[`row', 5]
				// same N regardless of controls
			matrix results[`row', 5] = e(N)
			local ++row
			local se_hat = _se[0.card_less] // reused below in randomization inference
			matrix results[`row', `j'] = `se_hat'
			local df = e(df_r)
			
			local ++row
			if `randinf' { // Randomization inference p-value
				randcmd ((card_less) reg `depvar' card_less  `controls', cluster(localidad)), ///
					treatvars(card_less) reps(`N_perm') seed(`seed')	
				matrix randinf_pvalues = e(RCoef)
				// Keep the randomization-t p-value 
				//  ("in practice I find the randomization-t to be superior to the -c" Young (2019))
				matrix results[`row', `j'] = randinf_pvalues[1,6] 	
			}
			else { // If not doing randomization inference, use regular p-value
				matrix results[`row', `j'] = `pvalue'
			}
		}
	}
	matlist results
	matlist pvalues

	// WRITE TO LATEX 
	if (`write') { // write Latex tables
		// Preliminaries
		local writeto "$tables/encasdu_`time'.tex"
		local u using `writeto'
		local o extracols(1) // for latexify
		local cc=1
		local tt=0
		
		// tokenize outcome_titles for row titles
		local _tt = 0
		foreach string of local outcome_titles {
			local ++_tt
			local `_tt' `"`string'"' // "
		}		

		foreach depvar of varlist `outcomes' {
			local ++tt	
			
			if `cc'==1 local _append replace
			else local _append append
			latexify results[`cc',1...] `u', ///
				title("{``tt''}") stars(pvalues[`cc',1...]) ///
				brackets("0 0 0 0 {}") ///
				format("%4.3f %4.3f %4.3f %4.3f %5.0fc") `_append'
			local ++cc
			latexify results[`cc',1...] `u', brackets("()") `o' format(%4.3f) append
			local ++cc
			latexify results[`cc',1...] `u', brackets("[]") `o' format(%4.3f) append
			local ++cc
		} 
	}		
}

*******************
** BALANCE TESTS **
*******************
if `balance_test' {
	use "$proc/encasdu_forreg.dta", clear

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
		regress ``var'_w' if card_less==1, cluster(localidad)
		matrix results[`row',1] = _b[_cons]
		matrix results[`=`row'+1',1] = _se[_cons]

		// Difference
		reg ``var'_w' ib1.card_less, cluster(localidad)
		matrix results[`row',2] = _b[0.card_less]
		matrix results[`=`row'+1',2] = _se[0.card_less]	
		local pvalue = 2*ttail(e(df_r), abs(_b[0.card_less]/_se[0.card_less]))
		matrix results[`row',3] = `pvalue'
		
		// Add randomization inference p-value
		if `randinf' {
			randcmd ((card_less) reg ``var'_w' card_less, cluster(localidad)), ///
				treatvars(card_less) reps(`N_perm') seed(`seed')	
			matrix randinf_pvalues = e(RCoef)
			// Keep the randomization-t p-value 
			//  ("Although in principle all randomization test statistics are
			//		equally valid, in practice I find the randomization-t to be superior
			//		to the -c" from Young (2019))
			matrix results[`=`row'+1', 3] = randinf_pvalues[1,6] 		
		}
		else { // If not doing randomization inference, use regular p-value
			matrix results[`=`row'+1', 3] = `pvalue'
		}
		local row = `row' + 2
	}

	matlist results

	// hack to get stars right
	matrix pvalues = J(`rows',3,.)
	matrix pvalues[1,3] = results[1...,3]
	matlist results
	matlist pvalues

	// tokenize balance_titles for row titles
	local _rr = 0
	foreach string of local balance_titles {
		local ++_rr
		local `_rr' `"`string'"' // "
	}
	local rr = 0
	local writeto "$tables/encasdu_balance_`time'.tex"
	local u using `writeto'
	if `write' {
		foreach var of local balance_list {
			local ++rr
			local row = `rr'*2 - 1
			if `rr'==1 local _append "replace"
			else local _append "append"
			
			#delimit ;
			// coefficients and p-values ;
			latexify results[`row',1...] `u', format("%3.2f %3.2f %3.2f") 
				stars(pvalues[`row',1...]) starcols(3) 
				title("{``rr''}") `_append'
			;
			// standard errors and randomization p-values;
			latexify results[`=`row'+1',1...] `u', format("%3.2f %3.2f %3.2f")
				brackets("() () []") extracols(1) append
			;
			#delimit cr
		}
	}
}

*************
** WRAP UP **
*************
log close
exit
