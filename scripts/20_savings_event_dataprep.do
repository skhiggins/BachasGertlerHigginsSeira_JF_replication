** DATA PREP FOR EVENT STUDY OF SAVINGS 
**  Sean Higgins

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 20_savings_eventstudy_dataprep
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
	local stats_list_bl `stats_list_bl' `var'_bl
}

// Randomization inference
local randinf = 1 // to create permutations file for randomization inference
local N_perm = 2000 // number of permutations
set seed 65099234 // random.org

**********
** DATA **
**********
use "$proc/netsavings_integrante_bimester`sample'.dta", clear

tab bimester

// Merge with bimester of switch
merge m:1 integranteid using "$proc/bim_switch_integrante.dta"
keep if _merge==3
drop _merge
sort integranteid bimester_redefined, stable
tab bim_switch
uniquevals integranteid, count sorted
drop if missing(bim_switch)
	// these are the ones in the 620,000 accounts who were not
	//  in localities that switched from cuentahorro to debicuenta
uniquevals integranteid, count sorted
drop if bim_switch < 13 // not very many obs; we know first switching
	// occurred Jan-Feb 2009 which is where we see the first 
	// substantial mass in the distribution of bim_switch,
	// so drop these odd few accounts where we get a bim_switch of
	// earlier than Jan-Feb 2009
uniquevals integranteid, count sorted
gen byte t = (bim_switch<=29) // treatment dummy; 
	// control switches beginning Nov-Dec 2011
	
uniquevals integranteid if t==0, count sorted
uniquevals integranteid if t==1, count sorted

// Merge with branch-level data
merge m:1 integranteid using "$proc/integrante_sucursal.dta"
keep if _merge==3
drop _merge
sort integranteid bimester_redefined, stable
by integranteid : gen tag = (_n==1)
uniquevals integranteid, count sorted // make sure we didn't lose any

// Merge with branch locality for clustering
merge m:1 sucadm using "$proc/branch_loc.dta"
uniquevals sucadm if _merge == 3
uniquevals sucadm if _merge == 1 // the problems; only 2
	// 145
	// 349
	// note in the full data set there are more (7 total)
	//  but v few observations of the other 5
tab sucadm if _merge == 1
uniquevals sucadm if _merge == 2
drop if _merge == 2

// Assume the few problem ones are in distinct locs
//  (innocuous since there are few)
replace branch_clave_loc = sucadm if _merge == 1
uniquevals branch_clave_loc
uniquevals sucadm

assert !missing(branch_clave_loc)
drop _merge

// Merge in baseline variables
merge m:1 integranteid using "$proc/bansefi_baseline.dta", /// 
	keepusing(`stats_list_bl')
if "`sample'"=="" assert _merge != 2
else drop if _merge == 2
gen mi_bl = (_merge != 3)
foreach var of local stats_list {
	// Some missing due to not having account yet in Jan 2008;
	//  to keep same sample when adding hh char x time, 
	//  recode as 0 and add missing dummy
	gen mi_`var'_bl = missing(`var')
	recode `var'_bl (. = 0)
}
drop _merge

// everything to cuatrimester
gen cuatrimester = floor(bimester/2) + 1
	// bimester 1 --> cuatrimester 1, bimester2, 3 --> cuatrimester 2, etc.
	//  (this is better than 1,2 --> 1, 3,4-->2 because the bimesters where payments where shifted
	//   are generally from an odd to previous even bimester
	//   and the switch to cards occurs in Nov-Dec AND Jan-Feb in both waves,
	//   so these two bimesters should be grouped
tab cuatrimester

gen cuat_switch = floor(bim_switch/2) + 1
tab cuat_switch if tag
gen cuat_since_switch = cuatrimester - cuat_switch 

// collapse bimester to 4-month period (averaging across bimesters)
sort integranteid cuatrimester, stable
tempvar mean_depvar_bycuat 
by integranteid cuatrimester : egen `mean_depvar_bycuat' = mean(net_savings_ind_0)
replace net_savings_ind_0 = `mean_depvar_bycuat'

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

uniquevals integranteid, count sorted // make sure we didn't lose any

gen _css = css if t==1 
replace _css = 0 if t==0 

// Demean the control vars
foreach var of local stats_list {
	summ `var' if mi_`var'_bl == 0
	replace `var'_bl = `var'_bl - r(mean) if mi_`var'_bl == 0
}

// Winsorize
foreach w in 1 5 { 
	winsify net_savings_ind_0, treatment(t) ///
		winsor(`w') gen(net_savings_ind_0_w`w') highonly
}

// Additional variables
gen net_savings_ind_0_ln = ln(net_savings_ind_0 + 1)
gen net_savings_ind_0_asinh = asinh(net_savings_ind_0)

// For regression
destring integranteid, gen(integranteid_num)
xtset integranteid_num cuatrimester
qui summ css if t==1 
local lo = r(min) 
local hi = r(max) 
// D^k_jt dummies
xi i.t*i.css, noomit  // doing it the old way rather than using # 
de _I*  // look at new vars created by xi 

**********
** SAVE **
**********
// Drop tempvars and other unneeded variables
drop __* f? n_days days?
compress
save "$proc/netsavings_forreg`sample'.dta", replace

***************************************************************
** GENERATE THE PERMUTATION FILE FOR RANDOMIZATION INFERENCE **
***************************************************************
if `randinf' cluster_permute cuat_switch ///
	using "$proc/netsavings_forreg_permutations`sample'.dta", ///
	cluster(branch_clave_loc) gentype(byte) n_perm(`N_perm') 
	
// Merge back into main data (to avoid having to merge in each parallelized instance)
use "$proc/netsavings_forreg`sample'.dta", clear
// Merge with permuted cuat_switch
merge m:1 branch_clave_loc using "$proc/netsavings_forreg_permutations`sample'.dta"
assert _merge == 3
drop _merge
save "$proc/netsavings_forreg_withperm`sample'.dta", replace

*************
** WRAP UP **
*************
log close
exit
