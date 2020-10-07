** DATA SET OF AVERAGE BALANCES
**  Pierre Bachas and Sean Higgins

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 07_bansefi_avgbal
cap log close
set linesize 200
log using "$logs/`project'_`time'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

************
** LOCALS **
************
local make_sample = 1

**********
** DATA **
**********
// Average balances (2009-2011)
//  Note: these are from the 2012 data dump
use "$data/Bansefi/Saldos Promedio Cuentahorro.dta", clear
append using "$data/Bansefi/Saldos Promedio Debicuenta.dta"

stringify cuenta, digits(10) replace // !user! written
	// converts cuenta to string variable with leading 0s when necessary
	//  (to match other data set)

// Convert wide data set to long (account-month)
local mm = 0
foreach var of varlist ene09-nov11 { // ene09-nov11 contain average balance for
									 //  the corresponding month (wide format)
	local ++mm
	rename `var' saldo_prom`mm'
}
reshape long saldo_prom, i(cuenta) j(month)

drop if month==35 // only have half of final bimester
gen bimester = ceil(month/2)
tab bimester
	
// days per month (to average across months correctly)
assert !missing(month)
rename month month_count
tab month_count
gen year = 2009 if month_count<=12
replace year = 2010 if month_count>12 & month_count<=24
replace year = 2011 if month_count>24
gen month = mod(month_count,12) // so month is 1-12 
replace month = 12 if month==0 
egen bom = bom(month year) // first day of month; !user! written -egenmore-
egen eom = eom(month year) // last day of month; !user! written -egenmore-
gen byte daysinmonth = eom - bom + 1
drop bom eom

collapse (mean) saldo_prom (rawsum) days_in_bimester = daysinmonth [pw=daysinmonth], ///
	by(cuenta bimester)
tab bimester
merge m:1 cuenta using "$proc/DatosGenerales.dta", keepusing(integranteid)
keep if _merge==3
drop _merge
replace bimester = bimester + 12 // so now Jan 2007 ==1

tab bimester

tempfile cuenta_bimester_09_11
save `cuenta_bimester_09_11', replace

// Average balances (2007-2008)
//  Note: these are from the 2015 data dump; didn't have these years before that
use "$proc/SP_2007.dta"
append using "$proc/SP_2008.dta" 
gen year = real(substr(aniomes,1,4))
gen month_in_year = real(substr(aniomes,5,2))
merge m:1 cuenta using "$proc/DatosGenerales.dta", ///
	keepusing(idarchivo integranteid)
assert _merge!=1
drop if _merge==2 // additional accounts in using (DatosGenerales)
keep if idarchivo==1 // ATM study accounts

gen month_count = 12*(year-2007) + month_in_year
gen bimester = ceil(month_count/2)

egen bom = bom(month_in_year year) // first day of month; !user! written -egenmore-
egen eom = eom(month_in_year year) // last day of month; !user! written -egenmore-
gen byte daysinmonth = eom - bom + 1
drop bom eom

rename salprom saldo_prom
collapse (mean) saldo_prom (rawsum) days_in_bimester = daysinmonth [pw=daysinmonth], ///
	by(integranteid cuenta bimester) // note unlike 2009-2011 average balances
		// these already have integranteid which is why we collapse on them rather
		// than merge them in after the collapse as we did above

// Combine the two data sets (2007-08 and 2009-11)
append using `cuenta_bimester_09_11'
save "$proc/avgbal_cuenta_bimester.dta", replace

tab bimester

// Collapse to integrante (client) level by summing across totals in the two accounts
sort integranteid bimester
** by integranteid bimester : assert days_in_bimester == days_in_bimester[1]
	// 3 contradictions in 3572568 observations
by integranteid bimester : gen byte problem_obs = !(days_in_bimester == days_in_bimester[1])
by integranteid bimester : replace problem_obs = problem_obs[_N]
count if problem_obs==1
list integranteid cuenta bimester days_in_bimester if problem_obs==1
	// Result: it's that for a few obs we only have one month in the 
	//  new account so days_in_bimester is 61 for one account and 30 for 
	//  the other. Thus use (max) when collapsing
collapse (sum) saldo_prom (max) days_in_bimester, ///
	by(integranteid bimester)
	
tab bimester

**********
** SAVE **
**********
save "$proc/avgbal_integrante_bimester.dta", replace

if `make_sample' {
	merge m:1 integranteid using "$proc/DatosGenerales_sample1.dta", ///
		keepusing(integranteid)
	tab _merge 
	keep if _merge==3
	drop _merge
	count
	describe
	save "$proc/avgbal_integrante_bimester_sample1.dta", replace
}

*************
** WRAP UP **
*************
log close
exit
