** BALANCE CHECKS OVER TIME RELATIVE TO CARD RECEIPT
**  Pierre Bachas and Sean Higgins

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 16_balance_checks_dataprep
cap log close
set linesize 200
log using "$logs/`project'_`time'`sample'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

************
** LOCALS **
************
// Randomization inference
local randinf = 1 // to create permutations file for randomization inference
local N_perm = 2000 // number of permutations
set seed 99559239 // random.org

************
** DATA **
************	
use "$proc/balance_checks`sample'.dta" , clear

// Sample selection
drop if cuatrimester >= 16 // IMPORTANT: Drop NOV-DEC 2011 (only have half of cuatrimester)

// Same day balance checks
tab same_day
tab year same_day

// Average amount of balance_checks
sum importe if bc == 1 , d
sort year, stable
by year: sum importe if bc == 1 , d

// Statistics of BC time from deposit 
tab time_from_deposit1 if bc == 1
tab time_from_deposit2 if bc == 1
tab time_from_deposit1 if bc == 1 & same_day == 0
tab time_from_deposit2 if bc == 1 & same_day == 0

// Note: construct histograms for appendix with time from deposit

cap drop _merge
merge m:1 integranteid using "$proc/integrante_sucursal.dta"
keep if _merge == 3
drop _merge

sort integranteid cuatrimester, stable
by integranteid : replace sucadm = sucadm[1] // since in very rare cases changes over time

// Merge in locality of branch
merge m:1 sucadm using "$proc/branch_loc.dta"
drop if _merge == 2
// Assume the few problem ones are in distinct locs
//  (innocuous since there are few)
replace branch_clave_loc = sucadm if _merge == 1
uniquevals branch_clave_loc
uniquevals sucadm
drop _merge

// Gen non_same_day bc
gen non_same_day_bc = .
replace non_same_day_bc = 0 if bc == 1 & same_day==1
replace non_same_day_bc = 1 if bc == 1 & same_day==0

// Collapse to get dataset from all transactions to the cuat_since_switch frequency

#delimit ;
collapse (sum) bc*,
	by(integranteid 
		cuat_since_switch cuatrimester /* note for a given combo of
			integranteid x cuat_since_switch, cuatrimester only takes 
			one value so including it here doesn't affect collapse
			but it is to keep the cuatrimester variable */
		bim_switch cuat_switch branch_clave_loc
	) 
;
#delimit cr
egen integranteid_num = group(integranteid) 
xtset integranteid_num cuat_since_switch  

// Balance panel: but values set to missing; recode missing to 0
tsfill
recode bc* (. = 0) 

sort integranteid cuat_since_switch, stable
local switch_vars bim_switch cuat_switch cuat_since_switch
foreach var of local switch_vars {
	by integranteid: replace `var' = `var'[_n-1] if `var' == .
}

tab cuat_since_switch
tab cuat_since_switch if bc!=. 

foreach bc of varlist bc* {
	rename `bc' sum_`bc'
}

*********** SAMPLE SELECTION AND ADJUSTMENTS ************************************	

drop if cuat_since_switch >= 6 // Only will look at 0-5 
drop if cuat_since_switch < 0 	

// MUTIPLY BY 4/3 first cuatrimester since people get it halfway through first bimester in cuatrimester (i.e. 1/4 of way through the cuatrimester)
foreach bc of varlist sum_bc* {
	replace `bc' = `bc'*(4/3) if cuat_since_switch == 0 
}

// Summary stats
summ sum_bc*
sort cuat_since_switch, stable
by cuat_since_switch: summ sum_bc*

// ADDED RESTRICTION
drop if bim_switch < 13 // pre-2009 before anyone switch according
	// to Prospera data. (Only 0.37% of observations.)
drop if cuat_switch < 10
	// For the cuat_switch < 10 observations, 
	//  balance checks had unknown code (?) before ND09 
	//  because they don't appear in data;
drop if cuat_switch >= 14
	// For these observations not enough post-periods 
	//  (since cuatrimester 15 is last period. For example,
	//   for cuat_switch == 14, there is only one more period so 
	//   k=1 would have to be the omitted period for those individuals
	//   which would bias the treatment effect toward 0)
	
recode sum_bc* (0 = .) if cuatrimester <= 9  

summ sum_bc*
sort cuat_since_switch, stable
by cuat_since_switch: summ sum_bc*	

**********
** SAVE **
**********
compress
save "$proc/balance_checks_forreg`sample'.dta", replace

***************************************************************
** GENERATE THE PERMUTATION FILE FOR RANDOMIZATION INFERENCE **
***************************************************************
// In this regression we only have treated accounts observed after treatment, 
//  so permute cuat_since_swtich at the branch_clave_loc x cuatrimester level
if `randinf' cluster_permute cuat_since_switch ///
	using "$proc/balance_checks_forreg_permutations`sample'.dta", ///
	cluster(branch_clave_loc cuatrimester) gentype(byte) n_perm(`N_perm') 
	
// Merge back into main data (to avoid having to merge in each parallelized instance)
use "$proc/balance_checks_forreg`sample'.dta", clear
// Merge with permuted cuat_switch
merge m:1 branch_clave_loc cuatrimester using "$proc/balance_checks_forreg_permutations`sample'.dta"
assert _merge == 3
drop _merge
save "$proc/balance_checks_forreg_withperm`sample'.dta", replace

*************
** WRAP UP **
*************
log close
exit
