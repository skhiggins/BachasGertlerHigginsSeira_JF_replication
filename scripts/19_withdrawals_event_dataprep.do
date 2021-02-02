** DATA PREP TO GENERATE GRAPHS OF WITHDRAWAL AND DEPOSIT DISTRIBUTIONS; EVENT STUDY FOR WITHDRAWALS
**  Pierre Bachas and Sean Higgins

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 19_withdrawals_event_dataprep
local sample $sample 
cap log close
set linesize 200
log using "$logs/`project'_`time'`sample'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

************
** LOCALS **
************
// Baseline variables that will be merged in
#delimit ;
local stats_list 
	N_client_deposits
	N_withdrawals
	proportion_wd 
	sum_Op_deposit
	net_savings_ind_0
	years_w_account
;
#delimit cr

foreach var of local stats_list {
	local mi_stats_list `mi_stats_list' mi_`var'_bl
	local stats_list_bl `stats_list_bl' `var'_bl
}

// Randomization inference
local randinf = 1 // to create permutations file for randomization inference
local N_perm = 2000 // number of permutations
set seed 30693435 // random.org

**********
** DATA **
**********
use "$proc/account_withdrawals_deposits`sample'.dta", clear

sort integranteid, stable
by integranteid : gen tag = (_n==1)

// everything to cuatrimester
gen cuatrimester = floor(bimester/2) + 1
	// bimester 1 --> cuatrimester 1, bimester2, 3 --> cuatrimester 2, etc.
	//  (this is better than 1,2 --> 1, 3,4-->2 because the bimesters where payments where shifted
	//   are generally from an odd to previous even bimester
	//   and the switch to cards occurs in Nov-Dec AND Jan-Feb in both waves,
	//   so these two bimesters should be grouped
drop if cuatrimester == 1
	
tab cuatrimester

gen cuat_switch = floor(bim_switch/2) + 1
tab cuat_switch if tag
gen cuat_since_switch = cuatrimester - cuat_switch 

// Demean the control vars
foreach var of local stats_list {
	summ `var' if mi_`var'_bl == 0
	replace `var'_bl = `var'_bl - r(mean) if mi_`var'_bl == 0
}

// collapse bimester to 4-month period
//  (averaging the average net balance, summing the transfer amount)
sort integranteid cuatrimester, stable
tempvar mean_depvar_bycuat with_per_deposit

foreach depvar of varlist *N_withdrawals* {
	if strpos("`depvar'", "_bl") continue // constant within obs anyway
	
	tempvar mean_depvar_bycuat 
	by integranteid cuatrimester : egen `mean_depvar_bycuat' = mean(`depvar')
	replace `depvar' = `mean_depvar_bycuat'
}
by integranteid cuatrimester : drop if _n>1 
	
summ cuat_since_switch , meanonly
local min = abs(r(min))
gen css = cuat_since_switch + `min' // dt factor var restrictions
local min_1 = `min' - 1
local min_2 = `min' - 2
di `min'
di `min_2'
// label the bss var for graphs
summ css, meanonly
forval cc=`r(min)'/`r(max)' {
	local css_label_local `css_label_local' `cc' "`=`cc'-`min''"
}
label define css_label `css_label_local'
label values css css_label

tab css, nolabel
tab css
tab cuat_since_switch
	
drop tag
by integranteid : gen tag = (_n==1)		

gen _css = css if t==1 
replace _css = 0 if t==0 

// Prepare for regression (xtset and create D^k_jt dummies)
destring integranteid, gen(integranteid_num)
xtset integranteid_num cuatrimester
xi i.t*i.css, noomit  // doing it the old way rather than using # 
de _I*  // look at new vars created by xi 

**********
** SAVE **	
**********
drop __*
compress
save "$proc/account_withdrawals_forreg`sample'.dta", replace

***************************************************************
** GENERATE THE PERMUTATION FILE FOR RANDOMIZATION INFERENCE **
***************************************************************
if `randinf' cluster_permute cuat_switch ///
	using "$proc/account_withdrawals_forreg_permutations`sample'.dta", ///
	cluster(branch_clave_loc) gentype(byte) n_perm(`N_perm') 
	
// Merge back into main data (to avoid having to merge in each parallelized instance)
use "$proc/account_withdrawals_forreg`sample'.dta", clear
// Merge with permuted cuat_switch
merge m:1 branch_clave_loc using "$proc/account_withdrawals_forreg_permutations`sample'.dta"
assert _merge == 3
drop _merge
save "$proc/account_withdrawals_forreg_withperm`sample'.dta", replace

*************
** WRAP UP **
*************
log close
exit
