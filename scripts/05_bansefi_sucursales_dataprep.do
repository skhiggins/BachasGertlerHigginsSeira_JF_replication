** CREATE DATA SET WITH BRANCHES
** Pierre Bachas and Sean Higgins

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 05_bansefi_sucursales_dataprep
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
use $proc/SP.dta, clear
assert !missing(sucadm)
merge m:1 cuenta using $proc/DatosGenerales

// cuenta-level (recall cuenta changes when they receive a card)
sort integranteid cuenta, stable
by integranteid cuenta : drop if _n>1 // duplicates drop
keep cuenta integranteid sucadm
order cuenta integranteid sucadm
save "$proc/cuenta_sucursal.dta", replace

if `make_sample' {
	preserve
	merge m:1 integranteid using "$proc/DatosGenerales_sample1.dta", ///
		keepusing(integranteid)
	tab _merge 
	keep if _merge==3
	drop _merge
	count
	describe
	save "$proc/cuenta_sucursal_sample1.dta", replace
	restore
}

// integrante-level 
by integranteid : drop if _n>1
keep integranteid sucadm
save "$proc/integrante_sucursal.dta", replace

if `make_sample' {
	preserve
	merge m:1 integranteid using "$proc/DatosGenerales_sample1.dta", ///
		keepusing(integranteid)
	tab _merge 
	keep if _merge==3
	drop _merge
	count
	describe
	save "$proc/integrante_sucursal_sample1.dta", replace
	restore
}

*************
** WRAP UP **
*************
log close
exit // !exit!
