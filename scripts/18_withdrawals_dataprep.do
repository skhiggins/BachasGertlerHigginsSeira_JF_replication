** DATA PREP FOR WITHDRAWALS AND DEPOSITS
**  Pierre Bachas and Sean Higgins
**  Created 15April2016

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 18_withdrawals_dataprep
local sample $sample 
cap log close
set linesize 200
log using "$logs/`project'_`time'`sample'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

************
** LOCALS **
************
#delimit ;

local Bank_list
	 10001 /* REINTEGRO CAJA: REINTEGRO EN EFECTIVO */
	 30003 /* CHQ. BANCARIO O CONFORMADO */
	230001 /* CUOTA PLAN DE PENSIONES */
	990001 /* ADEUDOS VARIOS */
;

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

// Deposits ;
local deposit_list 
	 10002 /* INGRESO EN EFECTIVO */
	230001 /* CUOTA PLAN DE PENSIONES */
	990002 /* ABONOS VARIOS */
;

// Baseline variables that will be merged in ;
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

// Confirmed by tabulating on full transactions data set that not missing any relevant codes

**********
** DATA **
**********
use "$proc/transactions_redef_bim`sample'.dta", clear // transaction level database,
merge m:1 integranteid using "$proc/bim_switch_integrante.dta" // Needed to Bring time of switch 	
keep if _merge == 3
drop _merge

mydi "Total transactions", stars(4) starchar("!")
count

// Use the codorigen to determine if bank or ATM transactions	
egen is_ATM = anymatch(codorigen), values(`ATM_list')
egen is_Bank = anymatch(codorigen), values(`Bank_list')
egen is_POS = anymatch(codorigen), values(`POS_list')
egen is_deposit = anymatch(codorigen), values(`deposit_list')

// Keep only relevant deposits and withdrawals
//  (for example, excludes balance checks; fees from bank)
keep if is_ATM == 1 | is_Bank == 1 | is_POS == 1 | is_deposit == 1 | missing(codorigen)
tab codorigen

// Group transactions of same type on same day into same transaction:
gsort integranteid date naturaleza -is_op_deposit
tempvar sum_importe
by integranteid date naturaleza : egen `sum_importe' = sum(importe)
by integranteid date naturaleza : drop if _n > 1 // duplicates drop but faster
	// (I did gsort -is_op_deposit above so that _n==1 would always be the Op deposit
	//  if applicable)
replace importe = `sum_importe'

tab codorigen cod_tx if importe<=50 & naturaleza == "D"

drop if importe <= 50 

** assert importe>0 & !missing(importe)
	** no contradictions 2007-2010; 
	** 11 contradictions in 9445755 observations in 2011
assert !missing(importe)
tab importe if !(importe>0) & !missing(importe) 
	// the 11 contradictions in 2011 are 0s
drop if importe == 0

// CODE TO CREAT SUMS 
****************************
** APPEND, COLLAPSE, SAVE **
****************************
// Account x bimester data set with redefined bimester timing
gen amt_deposit = . 
replace amt_deposit = importe if pos_deposit==1
	// neads to be missing for withdrawals so that collapse (mean) doesn't include it in the mean
gen amt_Op_deposit = .
replace amt_Op_deposit = importe if is_op_deposit==1
gen amt_client_deposit = .
replace amt_client_deposit = importe if is_client_deposit==1
gen amt_withdraw = .
replace amt_withdraw = importe if pos_withdrawal==1
	// needs to be missing for deposits (see above)
sort integranteid date 
by integranteid : replace sucadm = sucadm[1] // since in very rare cases the administering branch
	// changes during the period, set the sucursal variable as the one corresponding to the 
	// earliest transaction in the account
// make sure all integranteid have same date_opened, sucursal
foreach var of varlist date_opened sucadm {
	tempvar tag1 tag2
	sort integranteid `var'
	by integranteid : gen `tag1' = _n
	by integranteid `var' : gen `tag2' = _n
	assert `tag1' == `tag2'
}
foreach x in deposit Op_deposit client_deposit withdraw {
	gen sum_`x' = amt_`x'
}
collapse (mean) amt_deposit amt_Op_deposit amt_client_deposit amt_withdraw ///
	(sum) sum_deposit sum_Op_deposit sum_client_deposit sum_withdraw ///
		pos_deposit pos_withdrawal is_op_deposit is_client_deposit, ///
	by(integranteid date_opened sucadm bimester_redefined bim_switch)
rename pos_deposit N_deposits
rename pos_withdrawal N_withdrawals
rename is_op_deposit N_Op_deposits
rename is_client_deposit N_client_deposits
foreach var of varlist N_* {
	tab `var'
}

sort integranteid bimester_redefined, stable
by integranteid bimester_redefined : assert _N==1 // no duplicates

***********
** MERGE **
***********
// Merge with branch-level data
merge m:1 integranteid using "$proc/integrante_sucursal`sample'.dta"
keep if _merge==3
drop _merge

// Merge in locality of branch
merge m:1 sucadm using "$proc/branch_loc.dta"
drop if _merge == 2 // not matched from using
// Assume the few problem ones are in distinct locs
//  (innocuous since there are few)
replace branch_clave_loc = sucadm if _merge == 1
uniquevals branch_clave_loc
uniquevals sucadm
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

// Sample selection: drop early and late 
drop if missing(bim_switch)
gen byte t = (bim_switch <= 29)
drop if bim_switch < 13 

gen bim_relative_switch = bimester_redefined - bim_switch
gen pos_time_switch = (bim_relative_switch >= 0 & !missing(bim_relative_switch))
replace pos_time_switch = . if t == 0	

// Winsorize
foreach w in 1 5 { // 99th and 95th
	foreach var of varlist N_withdrawals N_client_deposits {
		_pctile `var', n(100)
		if r(r`=100-`w'') > 0 {
			winsify `var', treatment(t) ///
				winsor(`w') gen(`var'_w`w') highonly
				// highonly because no negatives
		}
		else {
			gen `var'_w`w' = `var'
		}
	}
}

// Additional variables
gen N_withdrawals_ln = ln(N_withdrawals + 1)
gen N_client_deposits_ln = ln(N_client_deposits + 1)

gen N_withdrawals_asinh = asinh(N_withdrawals)
gen N_client_deposits_asinh = asinh(N_client_deposits)
	
**********
** SAVE **
**********
describe
save "$proc/account_withdrawals_deposits`sample'.dta", replace // by original bimester timing

*************
** WRAP UP **
*************
log close
exit
