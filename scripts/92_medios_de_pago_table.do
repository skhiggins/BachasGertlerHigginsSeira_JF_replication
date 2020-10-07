** TABLES FROM PAYMENT METHODS SURVEY
** Sean Higgins
**  February 2020

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 92_medios_de_pago_table
cap log close
set linesize 200
log using "$logs/`project'_`time'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

************
** LOCALS **
************
#delimit ;
local outcome_titles
	`"
	"Fees to check balance (pesos)" 
	"Fees to withdraw (pesos)"
	"Balance checks without withdrawing"
	"Hard to use ATM"
	"Gets help using ATM"
	"Knows PIN"
	"'
;
local balance_titles
	`"
	"Number of household members"
	"Age of beneficiary"
	"Beneficiary is male"
	"Beneficiary is married"
	"Education level of beneficiary"
	"'
;	
// Outcomes;
local outcomes 
	fees_check
	fees_withdraw
	check_nowithdrawal
	hard_use_ATM 
	help_ATM 
	knows_PIN
;
local rows = wordcount("`outcomes'");
// Balance variables;
local balance_list
	t201
	t301
	male
	married
	escolaridad
;
#delimit cr

**********
** DATA **
**********
foreach pre in medios_de_pago medios_de_pago_balance {
	foreach suf in results pvalues {
		use "$proc/`pre'_`suf'.dta", clear
		mkmat *, matrix(`pre'_`suf')
	}
}

// WRITE TO LATEX 
local writeto "$tables/medios_de_pago_`time'.tex"
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

foreach depvar of local outcomes {
	local ++tt	
	
	if `cc'==1 local _append replace
	else local _append append
	latexify medios_de_pago_results[`cc',1...] `u', ///
		title("{``tt''}") stars(medios_de_pago_pvalues[`cc',1...]) ///
		brackets("0 0 0 0 {}") ///
		format("%3.2f %3.2f %3.2f %3.2f %5.0fc") `_append'
	local ++cc
	latexify medios_de_pago_results[`cc',1...] `u', ///
		brackets("()") `o' format("%3.2f") append
	local ++cc
	latexify medios_de_pago_results[`cc',1...] `u', ///
		brackets("[]") `o' format("%3.2f") append
	local ++cc
} 

// Balance tests
// tokenize balance_titles for row titles
local _rr = 0
foreach string of local balance_titles {
	local ++_rr
	local `_rr' `"`string'"' // "
}
local rr = 0
local writeto "$tables/medios_de_pago_balance_`time'.tex"
local u using `writeto'

foreach var of local balance_list {
	local ++rr
	local row = `rr'*2 - 1
	if `rr'==1 local _append "replace"
	else local _append "append"
	
	#delimit ;
	// coefficients and p-values ;
	latexify medios_de_pago_balance_results[`row',1...] `u', format("%3.2f") 
		stars(medios_de_pago_balance_pvalues[`row',1...]) starcols(3) 
		title("{``rr''}") `_append'
	;
	// standard errors and randomization p-values;
	latexify medios_de_pago_balance_results[`=`row'+1',1...] `u', format("%3.2f")
		brackets("() () []") extracols(1) append
	;
	#delimit cr
}

*************
** WRAP UP **
*************
log close
exit

