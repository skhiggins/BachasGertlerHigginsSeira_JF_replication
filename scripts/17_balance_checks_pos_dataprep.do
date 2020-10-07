** DATA PREP FOR EVENT STUDY OF BALANCE CHECKS RELATIVE TO POS TRANSACTION
**  Sean Higgins

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 17_balance_checks_pos_dataprep
cap log close
set linesize 200
log using "$logs/`project'_`time'`sample'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

************
** LOCALS **
************
#delimit ;
local trans_types
	bc
	ATM
	POS
;
#delimit cr

**********
** DATA **
**********
use "$proc/transactions_by_day`sample'.dta", clear

foreach trans_type of local trans_types {
	assert !missing(n_day_`trans_type')
	gen byte has_day_`trans_type' = (n_day_`trans_type' > 0) 
	assert !missing(n_bim_`trans_type')
	gen byte has_bim_`trans_type' = (n_bim_`trans_type' > 0)
	
	sort has_day_`trans_type' integranteid bimester_redefined date, stable
	by has_day_`trans_type' integranteid bimester_redefined (date): ///
		gen order_`trans_type' = _n if (has_day_`trans_type' == 1)

	sort integranteid bimester_redefined date, stable

	// Check when in bimester POS transaction is made
	tab day_of_bim if (has_day_`trans_type' == 1) & (order_`trans_type' == 1)
	** histogram day_of_bim if (has_day_`trans_type' == 1) & (order_`trans_type' == 1)

	// days since POS transaction
	gen days_since_`trans_type' = 0 if (has_day_`trans_type' == 1) & (order_`trans_type' == 1)
	by integranteid : ///
		replace days_since_`trans_type' = days_since_`trans_type'[_n - 1] + 1 if missing(days_since_`trans_type')

	// days before POS transaction
	gen neg_date = -date
	sort integranteid bimester_redefined neg_date, stable
	gen days_before_`trans_type' = 0 if (has_day_`trans_type' == 1) & (order_`trans_type' == 1)
	by integranteid : ///
		replace days_before_`trans_type' = days_before_`trans_type'[_n - 1] - 1 if missing(days_before_`trans_type')
	drop neg_date
	sort integranteid bimester_redefined date, stable

	// days_rel using closer transaction
	gen days_rel_`trans_type' = days_since_`trans_type' 
	replace days_rel_`trans_type' = days_before_`trans_type' if ///
		(abs(days_before_`trans_type') < days_since_`trans_type') | /// since days_before is negative
		missing(days_since_`trans_type')
		// so if both days_before and days_since missing, days_rel will be missing

	assert n_bim_`trans_type' == 0 if missing(days_rel_`trans_type')
}

**********
** SAVE **
**********
save "$proc/transactions_by_day_forreg`sample'.dta", replace
