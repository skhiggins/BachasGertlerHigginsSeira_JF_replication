** CREATE NET SAVINGS VARIABLE (SUBTRACTING MECHANICAL EFFECT)
**  Created 21mar2016

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 10_bansefi_net_savings
cap log close
set linesize 200
log using "$logs/`project'_`time'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

************
** LOCALS **
************
local fast = 0
local make_sample = 1
	
#delimit ;
local mechanical_effect_keep 
	importe? 
	f?
	days?
	prop?
	pattern
	*mechanical*
	n_days
;
#delimit cr

**********
** DATA **
**********
use "$proc/mechanical_effect`sample'.dta", clear
keep integranteid bimester* `mechanical_effect_keep'
di "test"
tab bimester_for_merge
** tab bimester_redefined
** clonevar bimester_for_merge = bimester_redefined
tempfile tomerge
save `tomerge', replace

use "$proc/avgbal_integrante_bimester`sample'.dta" // note already uses redefined bimesters
clonevar bimester_for_merge = bimester
merge 1:1 integranteid bimester_for_merge ///
	using `tomerge', ///
	keepusing(`mechanical_effect_keep') ///
	gen(merge_mechanical)
// Investigate merge:
forval mm=1/3 {
	mydi "merge_mechanical==`mm'"
	tab bimester_for_merge if merge_mechanical==`mm'
} // merge_mechanical==1 are not in average balance data set;
  // merge_mechanical==2 are bimester 30, 31
keep if merge_mechanical==3
// Consolidate to one bimester variable
//  (for mechanical effects it is based on the redefined bimesters;
//   for average balances it is based on standard bimesters because it is
//   not possible to define redefined bimesters)
rename bimester_for_merge bimester_redefined

foreach var of varlist *mechanical_effect* {
	recode `var' (missing = 0)
		// these are those who had no pattern or one of the rare patterns
}

gen net_savings_ind = saldo_prom - mechanical_effect_shifted
	// Note mechanical_effect_shifted = mechanical_effect + temp_mechanical
	//  where temp_mechanical is from the shifted payments
// version with -ves replaced with 0:
clonevar net_savings_ind_0 = net_savings_ind
replace net_savings_ind_0 = 0 if net_savings_ind < 0

foreach var of varlist *net_savings* {
	mydi "PROPORTION THAT ARE PROBLEMS `var'", s(4)
	count if !missing(`var') & !missing(saldo_prom)
	local tot = r(N)
	count if `var' < 0 & !missing(`var') & !missing(saldo_prom)
	di r(N)/`tot'
	
	summ `var'
}

fre pattern if net_savings_ind < 0, descending

save "$proc/netsavings_integrante_bimester.dta", replace

if `make_sample' {
	merge m:1 integranteid using "$proc/DatosGenerales_sample1.dta", ///
		keepusing(integranteid)
	tab _merge 
	keep if _merge==3
	drop _merge
	count
	describe
	save "$proc/netsavings_integrante_bimester_sample1.dta", replace
}

*************
** WRAP UP **
*************
cap log close
exit

