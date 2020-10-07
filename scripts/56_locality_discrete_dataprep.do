** LOCALITY-LEVEL DISCRETE TIME HAZARD: DATA PREP
**  Sean Higgins

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 56_locality_discrete_dataprep
cap log close
set linesize 200
log using "$logs/`project'_`time'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

**********
** DATA **
**********
use "$proc/locality_chars.dta", clear
tab bimswitch

merge m:1 localidad using "$proc/bdu_loc_allgiro_wide.dta"
drop _merge

keep if pobtot_2005 > 15000 & !missing(pobtot_2005) & ///
	!missing(bimswitch) & (bimswitch < 20124) 
count // 245
	
gen year_switch = floor(bimswitch/10)
gen bim_switch  = mod(bimswitch, 10)

gen change_ln_pobtot = ln_pobtot_2010 - ln_pobtot_2005
gen change_pos = pos_2008_6 - pos_2006_6
gen change_ln_pos = ln_pos_2008_6 - ln_pos_2006_6

gen ln_n_bansefi = log(n_bansefi + 1)

// Merge in number of branches
gen municipio = substr(localidad, 1, 5)
merge m:1 municipio using "$proc/cnbv_branch_mun.dta"
	// just 18 not matched from master, seems OK
count if _m==3 & missing(branches_2006) // these are the ones 
		// that had problems with matching by locality string
drop if _merge==2 // other muns, not in rollout
foreach var of varlist *branches* {
	replace `var' = 0 if _merge==1 & missing(`var') // since it's log+1, this works
		// for the log vars also
	gen missing_`var' = missing(`var') & _merge==3 // these are the ones w prob merging
		// by localidad string in cnbv_merge_locality.R
}
gen change_ln_branches = ln_branches_2008 - ln_branches_2006
replace change_ln_branches = 0 if missing(change_ln_branches) // and will incl 
	// a dummy for missing_branches_2006 (none with _merge==3 have missing_branches_2008)
drop _merge

// Merge in number of accounts
merge m:1 municipio using "$proc/cnbv_accounts_mun.dta"
	// just 23 not matched from master, seems OK
count if _m==3 & missing(accounts_2006) // 0
drop if _merge==2 // other muns, not in rollout
foreach var of varlist *accounts* {
	replace `var' = 0 if _merge==1 & missing(`var') // since it's log+1, this works
		// for the log vars also
	gen missing_`var' = missing(`var') & _merge==3 // these are the ones w prob merging
		// by localidad string in cnbv_merge_locality.R
}
gen change_ln_accounts = ln_accounts_2008 - ln_accounts_2006
replace change_ln_accounts = 0 if missing(change_ln_accounts) // and will incl 
	// a dummy for missing_branches_2006 (none with _merge==3 have missing_branches_2008)
drop _merge

// Merge in number of checking
merge m:1 municipio using "$proc/cnbv_checking_mun.dta"
	// just 23 not matched from master, seems OK
count if _m==3 & missing(checking_2006) // 0
drop if _merge==2 // other muns, not in rollout
foreach var of varlist *checking* {
	replace `var' = 0 if _merge==1 & missing(`var') // since it's log+1, this works
		// for the log vars also
	gen missing_`var' = missing(`var') & _merge==3 // these are the ones w prob merging
		// by localidad string in cnbv_merge_locality.R
}
gen change_ln_checking = ln_checking_2008 - ln_checking_2006
replace change_ln_checking = 0 if missing(change_ln_checking) // and will incl 
	// a dummy for missing_branches_2006 (none with _merge==3 have missing_branches_2008)
drop _merge

// Merge in number of ATMs
merge m:1 municipio using "$proc/cnbv_atms.dta"
	// just 14 not matched from master
drop if _merge == 2
replace atm = 0 if missing(atm)
gen ln_atm = log(atm + 1)
drop _merge

// Merge in other vars
merge m:1 municipio using "$proc/cnbv_baseline_mun.dta"
drop if _merge == 2
foreach var of varlist branch_number cards_credit atm_number cards_debit ///
	people_contracted people_terceros {
		replace `var' = 0 if missing(`var')
		gen ln_`var' = log(`var' + 1)
}
replace cards_all = cards_debit + cards_credit
gen ln_cards_all = log(cards_all + 1)
drop _merge

// Merge in political party
merge m:1 municipio using "$proc/elections_party_wide.dta"
drop if _merge == 2
gen change_partido_pan = partido_pan_2008 - partido_pan_2006
drop _merge

foreach var of varlist pct_* *partido* {
	replace `var' = `var'*100 // decimal to %
}

**********
** SAVE **
**********
save "$proc/locality_for_discretetime.dta", replace

*************
** WRAP UP **
*************
log close
exit
