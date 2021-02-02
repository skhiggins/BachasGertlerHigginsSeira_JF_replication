** CONSTRUCT TRANSACTIONS FOR LOTTERY ACCOUNTS USING TRANSACTIONS DATA
**  Sean Higgins
**  Created 16mar2017

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 21_bansefi_nonOp_transactions
local sample $sample 
set linesize 200
cap log close
log using "$logs/`project'_`time'`sample'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

************
** LOCALS **
************
local startyear 2007
local endyear   2015
local makesample = 1

**********
** DATA **
**********
if `makesample' { // draw random 1% of accounts
	set seed 12345
	use "$proc/DatosGenerales.dta", clear
	keep if idarchivo==2 // the accounts relevant for lottery study
	sample 1 // 1% sample
	count
	save "$proc/DatosGenerales_sample1.dta", replace
}
forval year = `startyear'/`endyear' {
	use "$proc/MOV`year'`sample'.dta", clear // transactions data from 2010
	merge m:1 cuenta using "$proc/DatosGenerales.dta"
	keep if idarchivo==2 // non-Oportunidades accounts
	tab _merge
		// makes sense to have not matched from using; these are the
		//  other idarchivos
	assert _merge!=1
	keep if _merge==3
	drop _merge
	tempfile transactions`year'
	save `transactions`year'', replace
}
forval year = `startyear'/`endyear' {
	if `year'==`startyear' use `transactions`year'', clear
	else append using `transactions`year''
}

**********
** SAVE **
**********
// Data set with all transactions for non-Oportunidades accounts
save "$proc/nonOp_transactions.dta", replace

if `makesample' {
	merge m:1 cuenta using "$proc/DatosGenerales_sample1.dta", ///
		keepusing(cuenta)
	keep if _merge==3 // only keeps the 1% sample
	count
	uniquevals cuenta
	drop _merge
	save "$proc/nonOp_transactions_sample1.dta", replace
}

*************
** WRAP UP **
*************
log close
exit

