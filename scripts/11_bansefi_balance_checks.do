** CREATE DATA SET OF BALANCE CHECKS AT THE TRANSACTION LEVEL 
**  Pierre Bachas and Sean Higgins

*********
** LOG **
*********
time
local project 11_bansefi_balance_checks
cap log close
set linesize 200
log using "$logs/`project'_`time'`sample'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

************
** LOCALS **
************
local day_window = 7 // how many days around POS transaction

#delimit ;
local trans_types
	balance_check
	ATM
	POS
	withdrawal
;

// List of balance check codes ;
local balance_check_list 
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

local withdrawal_list 
	`ATM_list'
	`POS_list' 
	10001  /* REINTEGRO EN EFECTIVO */
	990001 /* ADEUDOS VARIOS */
	. /* missing (12% of obs) */
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

**********************
**   (1) 	DATA    **
**********************
use "$proc/transactions_redef_bim`sample'.dta", replace

tab bimester_redefined

merge m:1 integranteid using $proc/bim_switch_integrante.dta // Needed to Bring time of switch 	
keep if _merge == 3
drop _merge

********************************
// Gen time and event variable
********************************

// Replace bimester_switch to starting date 1st of 2009, Since data on balance check only available after switch
// replace bim_switch = bim_switch - 12
// drop if bim_switch<= 0
	
gen cuatrimester = floor(bimester_redefined/2) + 1
gen cuat_switch = floor(bim_switch/2) + 1

gen bim_since_switch = bimester_redefined - bim_switch 
gen cuat_since_switch = cuatrimester - cuat_switch 	

tab cuat_since_switch
tab cuat_since_switch bim_switch

*** ISSUE: Need to create a balanced sample (Fill in missing zeros if should exist in period) 
egen tag = tag(integranteid)
tab cuat_switch if tag==1
drop tag

********************************
// Gen balance checks
********************************

// Balance checks
gen balance_check = 0
replace balance_check = 1 if inlist(codorigen, `balance_check_list_comma')
sort integranteid date, stable
by integranteid: egen N_balance_check = total(balance_check)
sum N_balance_check

// Same day balance checks
sum importe, d
sum importe if balance_check == 1, d
drop if importe <= 3  // Since smallest BC is above 3

tab codorigen, missing

gen withdrawal = 0
replace withdrawal = 1 if naturaleza == "D" & inlist(codorigen, `withdrawal_list_comma') 

sum importe if withdrawal==1, d

sort integranteid date, stable
by integranteid date: egen max_with = max(withdrawal) // 0 if any other type of transaction is occuring on that day (Note: maybe could refine?)	
gen same_day = .
replace same_day = 0 if balance_check == 1 & max_with == 0
replace same_day = 1 if balance_check == 1 & max_with == 1
drop max_with

*************************
// Gen time from deposit 
*************************

// Gen deposit
rename is_op_deposit deposit
// gen deposit = 0
// replace deposit =1 if balance_check == 0 & naturaleza == "H" & importe>=300

by integranteid: gen cum_deposit = sum(deposit)

// Positive date: how much past last deposit
gen date_deposit1 = .
replace date_deposit1 = date if balance_check == 0 & deposit==1

by integranteid: replace date_deposit1 = date_deposit1[_n-1] if date_deposit1 == .

// Negative date: how much before next deposit
gen date_deposit2 = .
replace date_deposit2 = date if balance_check == 0 & deposit==1

gen neg_date = -date
sort integranteid neg_date, stable
by integranteid: replace date_deposit2 = date_deposit2[_n-1] if date_deposit2 == .

// Gen time from deposit 
gen time_from_deposit1 = date - date_deposit1
gen time_from_deposit2 = date - date_deposit2	

****************************
// Gen time from withdrawal
****************************
gen date_withdrawal1 = .
replace date_withdrawal1 = date if balance_check == 0 & withdrawal==1

sort integranteid date, stable
by integranteid: replace date_withdrawal1 = date_withdrawal1[_n-1] if date_withdrawal1 == .
gen time_from_withdrawal1 = date - date_withdrawal1

sort integranteid date, stable

// Since some bimesters have multiple payments and payment dates can be shifted around across bimesters, 
//  balance check can be both after a transfer and before a transfer. 
//  Hence, set cutoff for how far before or after to consider
local cutoff_before = -20 

gen bc_pos_time = ((time_from_deposit2 < `cutoff_before') | missing(time_from_deposit2)) ///
	& (balance_check == 1 & same_day == 0) 
	// note that missing(time_from_deposit2) occurs if it's the end of the sample, 
	//  and we observe an extra bimester's worth of deposits in nov-dec 2011 that get dropped for
	//  event study since they're only half of a cuatrimester. So we want to keep missing(time_from_deposit2)
	//  as not being within 20 days prior to a transfer
tab bc_pos_time if balance_check == 1 & same_day == 0

// To explicitly graph the ones being excluded by each definition // added by Sean
gen bc_same_day = (balance_check == 1 & same_day == 1)
gen bc_not_same_day = (balance_check == 1 & same_day == 0)
gen bc_neg_time = (bc_pos_time == 0 & balance_check == 1 & same_day == 0)

**********************************************************************************************************************
// First withdrawal following a deposit (create by assigning within a date_deposit1) 
**********************************************************************************************************************
tempvar withdrawal_after_deposit_date
gen `withdrawal_after_deposit_date' = . 
replace `withdrawal_after_deposit_date' = date if balance_check == 0 & withdrawal==1

sort integranteid date_deposit1, stable
by integranteid date_deposit1: egen date_first_with = min(`withdrawal_after_deposit_date') 
gen time_from_first_with = date - date_first_with

sort integranteid bimester_redefined, stable
by integranteid bimester_redefined: egen date_first_with_bim = min(`withdrawal_after_deposit_date') 
gen time_from_first_with_bim = date - date_first_with_bim

gen bc_pos_time_wd = (time_from_first_with > 0 & !missing(time_from_first_with) & balance_check == 1 & same_day == 0)	
	// note missing(time_from_first_with_bim) are the ones that had no withdrawal between deposits

// To explicitly graph the ones being excluded by each definition // added by Sean
gen bc_neg_time_wd = (time_from_first_with < 0 | missing(time_from_first_with)) & balance_check == 1 & same_day == 0

**********************************************************************************************************************
// In bimester of POS transaction or within 7 days before or same day as POS transaction, not same day as ATM
**********************************************************************************************************************
gen byte is_POS = inlist(codorigen, `POS_list_comma')
by integranteid bimester_redefined: egen has_bim_POS = max(is_POS)
tab has_bim_POS

gen bc_in_POS_bim = (has_bim_POS == 1 & balance_check == 1 & same_day == 0)
gen bc_not_in_POS_bim = (has_bim_POS == 0 & balance_check == 1 & same_day == 0)

sort integranteid bimester_redefined is_POS date, stable
by integranteid bimester_redefined is_POS (date): ///
	gen order_POS = _n if is_POS == 1
tab order_POS

sort integranteid bimester_redefined date, stable

gen bc_before_POS = 0
gen bc_not_before_POS = (balance_check == 1 & same_day == 0) // will be replaced with 0s below 
	// if within 1 week of POS transaction

levelsof order_POS, local(n_bim_POS_levels)
foreach n_ of local n_bim_POS_levels {
	tempvar date_POS`n_'
	gen `date_POS`n_'' = date if is_POS == 1 & order_POS == `n_'
	by integranteid bimester_redefined: egen date_POS`n_' = min(`date_POS`n_'') // will only be one per bim;
		// this is just to assign that value for all transactions in bim
	replace bc_before_POS = 1 if (balance_check == 1 & same_day == 0) & ///
		(date - date_POS`n_' >= -`day_window') & (date - date_POS`n_' <= 0) // within X days before or day of POS transaction
	replace bc_not_before_POS = 0 if (balance_check == 1 & same_day == 0) & ///
		(date - date_POS`n_' >= -`day_window') & (date - date_POS`n_' <= 0) // within X days before or day of POS transaction
}
count if balance_check == 1 & same_day == 0
local tot = r(N)
count if bc_not_before_POS == 1
di r(N)/`tot' 

rename balance_check bc // for other files

*******************************************************
// Save Data to load to produce graphs
*******************************************************
drop __* // tempvars
drop date_POS*
save "$proc/balance_checks`sample'.dta" , replace
			
*************
** WRAP UP **
*************
log close
exit
