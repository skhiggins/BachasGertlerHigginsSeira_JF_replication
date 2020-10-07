** MAKE 1% SAMPLE: ALL TRANSACTIONS IN 1% OF OUR BANK ACCOUNTS TO TEST CODE ON LAPTOP BEFORE RUNNING ON SERVER
** Sean Higgins

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 04_bansefi_make_sample
cap log close
set linesize 200
log using "$logs/`project'_`time'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

************
** LOCALS **
************
local datosgenerales = 1 // !change! to 1 to create sample in DatosGenerales
	// (required on first run because this sample file is used to create the
	//  movimientos and saldos sample files)
local movimientos = 1 // !change! to 1 to create sample of MOV`year' files
local saldos = 1 // !change! to 1 to create sample of SP_`year' files

************************
** SAMPLE OF ACCOUNTS **
************************
if `datosgenerales' {
	use "$proc/DatosGenerales.dta", clear
	keep if idarchivo==1 // the original accounts we sent them
	dupcheck cuenta, assert
	// keep the switchers (since they have different account numbers before & after switch)
	keep if grupo==3
	tempfile switchers 
	save `switchers', replace

	use "$proc/DatosGenerales.dta", clear
	keep if idarchivo==1 // the original accounts we sent them
	bys integranteid: drop if _n>1 // second accounts (only switchers have these)
	sample 1
	tempfile sampled
	save `sampled', replace

	// Attach the other account for switchers
	use `switchers', clear
	merge m:1 cuenta using `sampled', keepusing(cuenta) keep(match)
	drop _merge
	tempfile switchers_sampled
	save `switchers_sampled', replace
	use `sampled', clear
	append using `switchers_sampled'
	bys cuenta: drop if _n>1 // since I appended both pre- and post-switch and one would
		// have already been in the data set
		
	save "$proc/DatosGenerales_sample1.dta", replace // !data!
		// so this data set has the 1% sample, where sampled switchers have 2 observations
		// (one with the pre-switch account number, another with post-switch account number)
}

****************************
** SAMPLE OF TRANSACTIONS **	
****************************
if `movimientos' {
	forval year=2007/2015 {
		di "`year'" // for debugging
		use $proc/MOV`year'.dta, clear
		merge m:1 cuenta using $proc/DatosGenerales_sample1.dta, keep(match)
			// keep(match) automatically selects only the 1% sample
		drop _merge 
		save $proc/MOV`year'_sample1, replace
			// didn't do as a tempfile because I want separate sample files for each year
			// so that my code distinguishing sample on laptop and full set on server will work
	}
	local i=0
	forval year=2007/2015 {
		local ++i
		if `i'==1 use $proc/MOV`year'_sample1, clear
		else append using $proc/MOV`year'_sample1
	}
	
	// SAVE
	save $proc/MOV_sample1.dta, replace
}

************************
** SAMPLE OF BALANCES **
************************
if `saldos' {
	forval year=2007/2015 {
		use $proc/SP_`year'.dta, clear
		merge m:1 cuenta using $proc/DatosGenerales_sample1.dta, keep(match)
			// keep(match) automatically selects only the 1% sample
		drop _merge 
		save $proc/SP_`year'_sample1, replace
	}
	local i=0
	forval year=2007/2015 {
		local ++i
		if `i'==1 use $proc/SP_`year'_sample1, clear
		else append using $proc/SP_`year'_sample1
	}
	
	// SAVE
	save $proc/SP_sample1.dta, replace
}

*************
** WRAP UP **
*************
log close
exit
