** EVENT STUDY OF BALANCE CHECKS RELATIVE TO POS/ATM TRANSACTION
**  Sean Higgins

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 84_balance_checks_pos_event
cap log close
local sample $sample 
set linesize 200
log using "$logs/`project'_`time'`sample'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

************
** LOCALS **
************
local day_window = 7 // how many days around POS transaction
local outcome "n_day_bc"
local bin = 0 // exclude control and bin beyond day_window instead
local not_atm_day = 1 // set to 1 to exclude balance checks on ATM days
local alpha = 0.05 // for confidence intervals

**********
** DATA **
**********
use "$proc/transactions_by_day_forreg`sample'.dta", clear
count // for N in table note (account by day observations)

// Summary stats:

// Number of balance checks 
summ `outcome'
local tot = r(sum)
di "Total balance checks"
di `tot'

summ `outcome' if days_rel_ATM == 0
local tot_same_day = r(sum)
di "Balance checks on same day as ATM withdrawal"
di `tot_same_day'
di `tot_same_day'/`tot'

summ `outcome' if days_rel_ATM != 0 & has_bim_POS == 0
local tot_no_POS = r(sum)
di "Balance checks not on same day as ATM withdrawal or same bimester as a POS"
di `tot_no_POS'
di `tot_no_POS'/`tot'

summ `outcome' if days_rel_ATM != 0 & has_bim_POS == 1
local tot_POS = r(sum)
di "Balance checks not on same day as ATM withdrawal or same bimester as a POS"
di `tot_POS'
di `tot_POS'/`tot'

summ `outcome' if days_rel_ATM != 0 & days_rel_POS >= -7 & days_rel_POS <= 0
local tot_not_before_POS = r(sum)
di "Balance checks not on same day as ATM withdrawal or same bimester as a POS"
di `tot_not_before_POS'
di `tot_not_before_POS'/`tot'

foreach trans_type in POS ATM {
	preserve

	tab days_rel_`trans_type'

	if !(`bin') {
		drop if (abs(days_rel_`trans_type') > `day_window') & !missing(days_rel_`trans_type')
	}
	else {
		replace days_rel_`trans_type' = -`day_window' if days_rel_`trans_type' < -`day_window'
		replace days_rel_`trans_type' = `day_window' if days_rel_`trans_type' > `day_window'
	}

	// Is it driven by balance checks on ATM withdrawal days?
	if (`not_atm_day' & "`trans_type'" != "ATM") replace `outcome' = 0 if has_day_ATM == 1
		// result from regression: still a spike before, but smaller

	// before event study-style regression, just look at the summary stats:
	local rows = 2*`day_window' + 1
	matrix results_means = J(`rows', 6, .) // empty matrix for results
	matrix colnames results_means = "k" "beta" "se" "p" "rcap_hi" "rcap_lo"
	local row = 0
	forval day = -`day_window'/`day_window' {
		mydi "`day'"
		local ++row

		// To make sure you get all days within 7 of a transaction (even if it's shortly after another
		//  transaction)
		if `day' < 0 local cond_var days_before_`trans_type'
		else local cond_var days_since_`trans_type'

		reg `outcome' if `cond_var' == `day', vce(cluster branch_clave_loc)
		local df = e(df_r)
		matrix results_means[`row', 1] = `day'
		// Beta (mean)
		matrix results_means[`row', 2] = _b[_cons]
		// Standard error
		matrix results_means[`row', 3] = _se[_cons]
		// P-value
		matrix results_means[`row', 4] = 2*ttail(`df', abs(_cons/_se[_cons]))
		// 95% confidence interval
		matrix results_means[`row', 5] = _b[_cons] + invttail(`df',`=`alpha'/2')*_se[_cons]
		matrix results_means[`row', 6] = _b[_cons] - invttail(`df',`=`alpha'/2')*_se[_cons]
	}

	** Prepare for event study 
	summ days_rel_`trans_type'
	local increment = abs(r(min))
	replace days_rel_`trans_type' = days_rel_`trans_type' + `increment'
		// now days_rel_POS = `increment' refers to the period of POS transaction
		//  (kind of annoying to have to do this; will need to 
		//   convert back when graphing)
	tab days_rel_`trans_type'

	xi i.has_bim_POS*i.days_rel_`trans_type', noomit
	describe _I* // look at the interaction variables created with xi

	// But since days_rel_POS is missing for control, 
	//  the _IhasXday* dummies also missing for control; we want them 
	//  to be 0
	if !(`bin') {
		recode _IhasXday* (. = 0) if has_bim_`trans_type'==0
	}
	else {
		drop if has_bim_`trans_type'==0
	}

	// To omit the period just before treatment:
	summ days_rel_`trans_type' if has_bim_`trans_type'
	local lo = r(min)
	local hi = r(max)
	//  And note that since k=0 is now =`increment', 
	//   k=-1 is `=`increment'-1', etc., which I use below
		
	// EVENT STUDY REGRESSION
	#delimit ;
	reghdfe `outcome'
		_IhasXday_1_`lo'-_IhasXday_1_`=`increment'-2'
		_IhasXday_1_`increment'-_IhasXday_1_`hi'
		, 
		absorb(
			integranteid_num /* individual fixed effects */
			day_of_bim /* day-of-bimester fixed effects */
			bimester_redefined /* bimester fixed effects */
		) 
		vce(cluster branch_clave_loc) /* clustered standard errors */
	;
	#delimit cr
	// Note the coefficients we want from the regression are 
	//  the coefficients on _IhasXday_1_*. 

	// Degrees of freedom for p-values and confidence intervals:
	local df = e(df_r)

	// PUT RESULTS IN A MATRIX
	local rows = `hi' - `lo' + 1
	matrix results_event = J(`rows', 6, .) // empty matrix for results_event
	matrix colnames results_event = "k" "beta" "se" "p" "rcap_hi" "rcap_lo"
	local row = 0
	forval p = `lo'/`hi' {
		local ++row
		local k = `p' - `increment' // original relative period (-6 to 7)
		matrix results_event[`row', 1] = `k'
		if `k' == -1 { // omitted period 
			matrix results_event[`row', 2] = 0 // beta
			matrix results_event[`row', 3] = 0 // se
			matrix results_event[`row', 4] = 1 // p
		}
		else { 
			// Beta (event study coefficient)
			matrix results_event[`row', 2] = _b[_IhasXday_1_`p']
			// Standard error
			matrix results_event[`row', 3] = _se[_IhasXday_1_`p']
			// P-value
			matrix results_event[`row', 4] = 2*ttail(`df', abs(_b[_IhasXday_1_`p']/_se[_IhasXday_1_`p']))
			// 95% confidence interval
			matrix results_event[`row', 5] = _b[_IhasXday_1_`p'] + invttail(`df',`=`alpha'/2')*_se[_IhasXday_1_`p']
			matrix results_event[`row', 6] = _b[_IhasXday_1_`p'] - invttail(`df',`=`alpha'/2')*_se[_IhasXday_1_`p']
		}
	}

	matlist results_event

	restore // needed to avoid applying `not_atm_day' if `trans_type' is ATM

	**********
	** SAVE **
	**********
	// Save means and event study to graph in another file
	foreach mm in means event {
		preserve
		clear
		svmat results_`mm', names(col)
		save "$proc/`outcome'_`trans_type'_`mm'`sample'.dta", replace
		restore
	}

}

*************
** WRAP UP **
*************
log close
exit
