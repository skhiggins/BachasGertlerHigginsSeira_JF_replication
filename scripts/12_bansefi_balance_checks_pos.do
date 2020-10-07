** NUMBER OF BALANCE CHECKS, ATM WITHDRAWALS, POS TRANSACTIONS BY ACCOUNT BY DAY
**  Sean Higgins

*********
** LOG **
*********
time
local project 12_bansefi_balance_checks_pos
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

// List of balance check codes ;
local bc_list 
	470015 /* CARGO CONS.SALDO CAJERO RED */
	470070 /* COMISION CONSULTA SALDO CAJERO BANSEFI [close to none in data] */
	480073 /* COMISION CONSULTA SALDO CAJERO RED */
	480076 /* COMISION CONSULTA SALDO CAJERO INTL */
	480090 /* COM CONSULTA SALDO CAJERO INTL */
; /* Note: other codes in the codebook that correspond to balance checks had no observations in the data */;


// ATM withdrawals ;
local ATM_list
	470001 /* DISPOSICION CAJERO RED - ATM withdrawal (non-Bansefi) */
	470003 /* DISPOSICION CAJERO BANSEFI - ATM withdrawal (Bansefi) */
	470005 /* DISPOSICION CAJERO INTERNACIONAL - ATM withdrawal (international) */
	470152 /* VENTA GENERICA CAJERO RED - generic ATM sale */ 
; /* note the 47 codes will have the amounts and 470021 and the 48 codes will have the fees, so don't count those */;

// POS transactions ;
local POS_list 
	470011 /* CONSUMO */
	470024 /* CONSUMO INTERNACIONAL */
;

#delimit cr

// Comma-separated lists

foreach trans_type of local trans_types {
	local `trans_type'_list_comma "" // empty list 
	local i = 0
	foreach nn of local `trans_type'_list {
		local ++i
		if `i'==1 local comma ""
		else local comma ","
		local `trans_type'_list_comma `"``trans_type'_list_comma'`comma'`nn'"' // "
	}
}

**********
** DATA **
**********
use "$proc/transactions_redef_bim`sample'.dta", replace

// Merge with bimester of switch
merge m:1 integranteid using "$proc/bim_switch_integrante.dta" // Needed to Bring time of switch 	
keep if _merge == 3
drop _merge

// Sample selection: drop early and late 
drop if missing(bim_switch)
gen byte t = (bim_switch<=29)
drop if bim_switch < 13 

// Not-yet-treated can't make balance checks, so restrict to periods after treatment
uniquevals integranteid // 348802
drop if bimester_redefined < bim_switch

uniquevals integranteid // 251985 (since control dropped above)
local n_i = r(unique)
uniquevals date // 805
local n_t = r(unique)
di "Max obs after fill: " %16.0fc `=`n_i'*`n_t'' // 202,847,925

// Create dummy variables for each transaction type, and a categorical variable
local i = 0
gen trans_type = 0
sort integranteid bimester_redefined date, stable
foreach trans_type of local trans_types {
	local ++i
	gen is_`trans_type' = 0
	replace is_`trans_type' = 1 if inlist(codorigen, ``trans_type'_list_comma')
	replace trans_type = `i' if is_`trans_type' == 1
	local label_list `label_list' `i' "`trans_type'"
	
	by integranteid bimester_redefined : egen n_`trans_type' = sum(is_`trans_type')
}
label define trans_types_ `label_list'
label values trans_type trans_types_	

// Day of bimester for day of bim fixed effects

gen bimester_in_year_redefined = mod(bimester_redefined, 6) + 6*(mod(bimester_redefined, 6) == 0)
assert inrange(bimester_in_year_redefined, 1, 6)
gen month_in_year_redefined = bimester_in_year_redefined*2 - 1
gen first_day_in_bim = min(mdy(month_in_year_redefined, 1, year_redefined), shift_date)
	// shift date is prior to the first of the month that would start the bim
	//  in the cases of a shifted bimester
format first_day_in_bim %td

gen day_of_bim = date - first_day_in_bim
assert day_of_bim >= 0 // sanity check
tab day_of_bim // max is 61

// Check distribution of POS transactions per bimester
tab n_POS
	// conditional on making POS transaction, about 1/2 only make 1 POS transaction in the bimester
	//  which is the simplest case to think about
	
// for simplicity, first do it just for first POS transaction in the bimester
sort integranteid bimester_redefined trans_type date, stable
by integranteid bimester_redefined trans_type (date): gen order_trans_by_type = _n 

collapse (sum) is_bc is_ATM is_POS, by(integranteid date /// i,t 
	date_opened /// constant within integranteid
	bimester_redefined first_day_in_bim day_of_bim /// constant within (integranteid, date)
	n_* /// constant within integranteid bimester_redefined
)
foreach trans_type of local trans_types {
	rename is_`trans_type' n_day_`trans_type' // since summed during collapse
}

egen integranteid_num = group(integranteid)
xtset integranteid_num date
count
tsfill // not full since some accounts enter and exit the data; 
	// don't want to count those as 0 balance checks
count // now much bigger, one obs for each account by day

// Replace the missings after tsfill:
sort integranteid_num integranteid, stable
by integranteid_num : replace integranteid = integranteid[_N] // since sorts empty strings on top

gen neg_date = -date
sort integranteid neg_date, stable // sort with -date is a trick to get correct bimester_redefined
by integranteid : carryforward bimester_redefined first_day_in_bim, back replace
drop neg_date
sort integranteid date, stable
by integranteid : replace bimester_redefined = bimester_redefined[_n - 1] if date < first_day_in_bim
by integranteid : replace first_day_in_bim = first_day_in_bim[_n - 1] if date < first_day_in_bim
assert date >= first_day_in_bim // sanity check after above line

sort integranteid bimester_redefined date, stable
foreach trans_type of local trans_types {
	by integranteid bimester_redefined : egen n_bim_`trans_type' = max(n_`trans_type')
	drop n_`trans_type'
	recode n_day_`trans_type' (. = 0)
}
tempvar date_opened
by integranteid : egen `date_opened' = max(date_opened)
replace date_opened = `date_opened'
assert !missing(first_day_in_bim)
replace day_of_bim = date - first_day_in_bim
assert day_of_bim >= 0 // sanity check
tab day_of_bim // very few obs ended up with >61 due to peculiarities
	// (e.g. no transaction in an account in a bimester); drop them
	// note the tab isn't perfectly balanced due to not using full with tsfill,
	//  so it's bounded by very first or last observation within an account
count 
local tot_obs = r(N)
count if day_of_bim > 61 
di r(N)/`tot_obs' // 0.8% (in both full data and 1% sample)
drop if day_of_bim > 61

// Merge with branch-level data
merge m:1 integranteid using "$proc/integrante_sucursal`sample'.dta"
keep if _merge==3
drop _merge

// Merge in locality of branch
merge m:1 sucadm using "$proc/branch_loc.dta"
drop if _merge == 2
// Assume the few problem ones are in distinct locs
//  (innocuous since there are few)
replace branch_clave_loc = sucadm if _merge == 1
uniquevals branch_clave_loc
uniquevals sucadm
drop _merge

**********
** SAVE **
**********
drop __* // tempvars
count // 120M account by day
uniquevals integranteid
describe
save "$proc/transactions_by_day`sample'.dta", replace

*************
** WRAP UP **
*************
log close
exit
