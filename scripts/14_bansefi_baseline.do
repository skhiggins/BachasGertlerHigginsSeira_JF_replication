** CREATE BASELINE MEASURES FROM BANSEFI DATA
**  Sean Higgins
**  Created 03nov2015

*********
** LOG **
*********
time
local project 14_bansefi_baseline
cap log close
set linesize 200
log using "$logs/`project'_`time'`sample'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

************
** LOCALS **
************
local transfer "sum_Op_deposit"
local depvar "net_savings_ind_0"

#delimit ;
local stats_list 
	N_client_deposits
	N_withdrawals
	N_withdraw_1
	N_withdraw_2
	N_withdraw_3
	proportion_wd 
	`transfer'
	`depvar'
	years_w_account
;
#delimit cr

local write = 1
local startyear 2007

**********
** DATA **
**********
use "$proc/netsavings_integrante_bimester`sample'.dta", clear

tab bimester

// Merge with bimester of switch
merge m:1 integranteid using "$proc/bim_switch_integrante`sample'.dta"
keep if _merge==3
drop _merge
tab bim_switch
drop if missing(bim_switch)
drop if bim_switch < 13 // not very many obs; we know first switching
	// occurred Jan-Feb 2009 which is where we see the first 
	// substantial mass in the distribution of bim_switch
gen byte t = (bim_switch<=29) // treatment dummy; 
	// control switches beginning Nov-Dec 2011

// Merge with branch-level data
merge m:1 integranteid using "$proc/integrante_sucursal`sample'.dta"
keep if _merge==3
drop _merge
sort integranteid bimester_redefined, stable
by integranteid : gen tag = (_n==1)

// Merge in locality of branch
merge m:1 sucadm using "$proc/branch_loc.dta"
drop if _merge == 2
// Assume the few problem ones are in distinct locs
//  (innocuous since there are few)
replace branch_clave_loc = sucadm if _merge == 1
uniquevals branch_clave_loc
uniquevals sucadm
drop _merge

stringify branch_clave_loc, digits(9) add(0) gen(localidad)

// Merge with transfer amounts (already by redefined bimester)
merge 1:1 integranteid bimester_redefined /// said m:1 but I think it's 1:1
	using "$proc/account_bimredef_transactions`sample'.dta"
// using only are transactions without a corresponding obs in the 
//  average bal data set
keep if _merge==3
drop _merge
recode N_* sum_* amt_* (. = 0) // in bimesters without that type of transaction

describe

// New variables
gen N_total_deposits = N_Op_deposits + N_client_deposits
gen N_withdraw_per_Op_deposit = N_withdrawals/N_Op_deposits
gen N_withdraw_per_deposit = N_withdrawals/N_deposits
gen year = `startyear' - 1 + ceil(bimester/6)
	// ceil(bimester/6) = 1 for bimester in [1,6],
	// ceil(bimester/6) = 2 for bimester in [7,12],
	// etc.
	
assert !missing(N_withdrawals)
gen N_withdraw_1 = (N_withdrawals == 1)
gen N_withdraw_2 = (N_withdrawals == 2)
gen N_withdraw_3 = (N_withdrawals >= 3) 

// COLLAPSE TO BASELINE
uniquevals integranteid
sort integranteid bimester_redefined, stable
by integranteid (bimester_redefined) : ///
	gen first_bimester = bimester_redefined if _n==1
tab first_bimester // see when people first show up in the data
	// problem: about 15% have their original account opened in 2009-10
	//  (anyone not the earliest switchers could become beneficiary early
	//   2009; anyone in wave 2 could become beneficiary late 2009 early 2010 ; 
	//   anyone in control could become beneficiary throughout 2010
	
assert bimester==bimester_redefined // any different in this data set?

// Baseline defined as first bimester of 2008
forval i=1/2 { // 2 definitions of baseline
	preserve 
	
	if `i'==1 { // Baseline as first bimester of 2008
		keep if year==2008 & bimester_redefined==7
		// since bimester_redefined = 1 is Jan-Feb 2007, 7 is Jan-Feb 2008
	}
	else { // Baseline as bimester before switching
		keep if bimester_redefined == bim_switch - 1
	}
	drop if bimester==1 // the weird one with shifted payment
	uniquevals integranteid // is it that some in non-earliest switchers
		// opened in 2009 and later?
		// Ans: yes it is, see tab first_bimester above
	collapse (mean) N_* sum_* amt_* `depvar', ///
		by(sucursal localidad t integranteid bim_switch date_opened)

	// time with account when switch
	decode bim_switch, gen(bim_switch_string)
	gen month_switch_string = substr(bim_switch_string,5,3)
		// they generally receive cards at beginning of 2nd month of bimester
	gen year_switch_string  = substr(bim_switch_string,-2,2)
	tab year_switch_string
	gen date_switch_string = "1 " + month_switch_string + " 20" + year_switch_string
	tab date_switch_string
	gen date_switch = date(date_switch_string,"DMY")
	gen days_w_account = date("01jan2008","DMY") - date_opened
	summ days_w_account, detail
	gen years_w_account = days_w_account/365.25

	gen proportion_wd = 100*(sum_withdraw/sum_deposit)

	// Percent making exactly X withdrawals
	foreach var of varlist N_withdraw_? {
		gen pct_`var' = `var'*100
	}
	
	
	foreach var of local stats_list {
		rename `var' `var'_bl
	}
	keep integranteid t localidad `stats_list'

	if `i'==1 {
		// Individual level
		save "$proc/bansefi_baseline`sample'.dta", replace
		
		// Locality level
		foreach var of local stats_list {
			rename `var'_bl `var'
		}
		// Create a locality level data set
		gen log_`depvar' = log(`depvar' + 1)

		#delimit ;
		collapse (mean) 
			`stats_list'
			log_`depvar', 
			by(localidad)
		;
		#delimit cr

		gen log_mean_`depvar' = log(`depvar')
		
		save "$proc/bansefi_baseline_loc`sample'.dta", replace
	}
	else {
		// Individual level
		save "$proc/bansefi_bimbefore`sample'.dta", replace
	}
	
	restore
}

*************
** WRAP UP **
*************
log close
exit
		
