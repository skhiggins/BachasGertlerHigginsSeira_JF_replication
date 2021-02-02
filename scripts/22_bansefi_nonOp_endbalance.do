** CONSTRUCT END OF MONTH BALANCE USING TRANSACTIONS DATA
**  Sean Higgins
**  Created 16mar2017

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 22_bansefi_nonOp_endbalance
local sample $sample 
set linesize 200
cap log close
log using "$logs/`project'_`time'`sample'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

************
** LOCALS **
************
local startyear = 2007
local endyear   = 2015
local makesample =   1

**********
** DATA **
**********
use "$proc/nonOp_transactions`sample'.dta", clear

gen double deposits = importe if naturaleza=="H"        // deposits
gen double withdrawals = importe if naturaleza=="D" // subtract withdrawals

gen date = date(fecha,"YMD")
format date %td
gen month = month(date) + 1*(day(date) >= 12)
gen year  = year(date)
replace year = year + 1 if month==13 // from 12 + 1 
replace month = 1 if month==13 // from 12 + 1 

// Create account-year panel of sum of deposits and withdrawals
keep cuenta year month deposits withdrawals
collapse (sum) deposits withdrawals , by(cuenta year month)
	// overall change in balance by account-month
gen double change = deposits - withdrawals

// Fill in missing panel obs (if an account has no transactions in a 
//  particular month, that account-month pair is missing from the 
//  data set)
gen month_counter = (year - `startyear')*12 + month // for xtset
	// month is 1,...,12,1,...,12,1,...
	// month_counter is 1,...,12,13,...,24,25,...
tab month_counter

destring cuenta, gen(double cuenta_num) // xtset doesn't accept strings
xtset cuenta_num month_counter
tsfill // fills in missing panel obs
	// i.e. if there was no transaction in a particular account-month,
	//  there will be no observation for that account-month in the
	//  collapsed data; this adds those observations
	// (not adding `, full` which would add 0s before first ever transaction and
	//  after last-ever transaction since this would likely be before/after account open
// Replace missing vars for tsfilled observations
recode deposits withdrawals change (. = 0) 
	// months with no transactions had 0 deposits, withdrawals, change
sort cuenta_num cuenta // the tsfilled ones will be missing cuenta
	// since cuenta is string, missings at top
by cuenta_num : replace cuenta = cuenta[_N] 
	// now non-missing for the tsfilled ones
sort cuenta month_counter
tempvar _mo _yr // as a double check that what I do is correct
gen `_mo' = mod(month_counter,12) + 12*(mod(month_counter,12)==0)
	// `_mo' is 1,...,12,1,... while month_counter is 1,...,12,13,...
gen `_yr' = `startyear' + floor((month_counter-1)/12)
	// reconstruct year from month_counter
assert `_mo'==month if !missing(month) // sanity check
assert `_yr'==year if !missing(year)
replace month = `_mo' if missing(month) // tsfilled observations
replace year  = `_yr' if missing(year)
drop `_mo' `_yr'
by cuenta : gen double ending_balance = sum(change)
summ ending_balance

// Ending balance by month
summ month_counter, meanonly
local months = r(max) - r(min) + 1 
matrix ending_balances = J(`months',3,.)
local mm = 0
forval i=`r(min)'/`r(max)' {
	local ++mm
	matrix ending_balances[`mm',1] = `i'
	summ ending_balance if month_counter==`i'
	matrix ending_balances[`mm',2] = r(N)
	matrix ending_balances[`mm',3] = r(mean)
}
matlist ending_balances

**********
** SAVE **
**********
save "$proc/nonOp_endbalance.dta", replace

if `makesample' {
	merge m:1 cuenta using "$proc/DatosGenerales_sample1.dta", ///
		keepusing(cuenta)
	keep if _merge==3 // only keeps the 1% sample
	count
	uniquevals cuenta
	drop _merge
	save "$proc/nonOp_endbalance_sample1.dta", replace
}

*************
** WRAP UP **
*************
log close
exit
