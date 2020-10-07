** READ IN RAW BANSEFI DATA GIVEN TO US SEPTEMBER 3 2015
** Sean Higgins
** Created 5sep2015

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 01_bansefi_saldos_dataprep
cap log close
set linesize 200
log using "$logs/`project'_`time'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

*************************
** READ & EXPLORE DATA **
*************************
quietly {
	forval year=2007/2015 {
		noisily mydi "`year'", lines(4) stars(4)
		// Read data
		clear
		#delimit ;
		infix /* note first ten columns of SP_`year'.txt are blank */
				str10  cuenta   10-19  /* Número de Cuenta BANSEFI                              */
				int    sucadm   20-23  /* Sucursal administra la cuenta                         */
				str6   aniomes  24-29  /* Periodo pertenece  saldo promedio (AAAAMM)            */
				double salprom  30-46  /* Saldo Promedio correspondiente (99999999999999.99)    */
			using "$data/Bansefi/SP_`year'.txt"
		;
		#delimit cr
		format salprom %16.2f
		// Check for missings
		foreach var of varlist * {
			noisily mydi "`var'", stars(3) starchar("!")
			count if mi(`var')
			local n_mi = r(N)
			count
			noisily di "Proportion missing: " `n_mi'/r(N)
			noisily exampleobs `var' if !mi(`var'), n(50)
		}
		save "$proc/SP_`year'.dta", replace
	}
}

***********
** MERGE **
***********
forval year = 2007/2015 {
	if `year'==2007 use "$proc/SP_`year'.dta"
	else append using "$proc/SP_`year'.dta"
}
save "$proc/SP.dta", replace

*************
** WRAP UP **
*************
log close
exit

