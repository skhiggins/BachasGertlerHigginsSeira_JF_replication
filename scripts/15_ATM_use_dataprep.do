** WITHDRAWALS AT ATMs OVER TIME
**  Pierre Bachas

*********
** LOG **
*********
time
local project 15_ATM_use_dataprep
local sample $sample 
cap log close
set linesize 200
log using "$logs/`project'_`time'`sample'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

************
** LOCALS **
************
local idvar integranteid
local timevar cuatrimestre

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

#delimit cr
	
********************
**    	DATA 		  **
********************

use "$proc/transactions_redef_bim`sample'.dta", replace

// Merge with bimester of switch
merge m:1 integranteid using "$proc/bim_switch_integrante.dta" // Needed to Bring time of switch 	
keep if _merge == 3
drop _merge

// Merge with branch-level data
merge m:1 integranteid using "$proc/integrante_sucursal`sample'.dta"
keep if _merge == 3
drop _merge

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

// Use the codorigen to determine if bank or ATM transactions	
egen is_ATM = anymatch(codorigen), values(`ATM_list')
egen is_Bank = anymatch(codorigen), values(`Bank_list')
egen is_POS = anymatch(codorigen), values(`POS_list')

gen ATM_withdrawal = .
replace ATM_withdrawal = 0 if is_Bank==1 & naturaleza == "D"
replace ATM_withdrawal = 0 if is_POS==1 & naturaleza == "D"
replace ATM_withdrawal = 1 if is_ATM==1 & naturaleza == "D"

gen POS_transaction = .
replace POS_transaction = 0 if is_Bank==1 & naturaleza == "D"
replace POS_transaction = 1 if is_POS==1 & naturaleza == "D"
replace POS_transaction = 0 if is_ATM==1 & naturaleza == "D"

label define ATM 0 "Bank withdrawal or POS transaction" 1 "ATM withdrawal"
label values ATM_withdrawal ATM	

label define POS 0 "Bank or ATM withdrawal" 1 "POS transaction"
label values POS_transaction POS

// Sample selection: drop early and late 
drop if missing(bim_switch)
gen byte t = (bim_switch<=29)
drop if bim_switch < 13 
	
gen bim_relative_switch = bimester_redefined - bim_switch
gen pos_time_switch = (bim_relative_switch >= 0 & bim_relative_switch!=. )
replace pos_time_switch  = . if t == 0

sort integranteid, stable
by integranteid : gen tag = (_n==1)

gen cuatrimester = floor(bimester_redefined/2) + 1
		// bimester 1 --> cuatrimester 1, bimester2, 3 --> cuatrimester 2, etc.
		//  (this is better than 1,2 --> 1, 3,4-->2 because the bimesters where payments where shifted
		//   are generally from an odd to previous even bimester
		//   and the switch to cards occurs in Nov-Dec AND Jan-Feb in both waves,
		//   so these two bimesters should be grouped
drop if cuatrimester == 1	

gen cuat_switch = floor(bim_switch/2) + 1
tab cuat_switch if tag
gen cuat_since_switch = cuatrimester - cuat_switch 

foreach outcome in ATM Bank POS {
	di "`outcome'"
	// Size of transaction
	summ importe if is_`outcome' == 1 & cuat_since_switch >= 0 & cuat_since_switch <= 5, d
}

// Collapse to one observation per account per cuatrimestre
// LOCALS
local idvar integranteid
local timevar cuatrimester 

sort `idvar' `timevar', stable

// Dummy
by `idvar' `timevar': egen used_ATM = max(ATM_withdrawal) 
by `idvar' `timevar': egen used_POS = max(POS_transaction) 

// Number transactions
by `idvar' `timevar': egen n_ATM = sum(ATM_withdrawal)
by `idvar' `timevar': egen n_POS = sum(POS_transaction)

tab ATM_withdrawal cuatrimester  if cuat_switch == 8, col
tab ATM_withdrawal cuatrimester  if cuat_switch == 13, col

tab ATM_withdrawal cuat_since_switch, col

** Only Keep one observation per client cuatrimestre	
egen tag_id_bim = tag(`idvar' `timevar')
keep if tag_id_bim == 1

************************
// Count observations 
************************
*** Number of observations (transactions) **********
count 
*** Number of unique IDs  **********
sort `idvar' `timevar', stable
by `idvar': gen nvals = _n == 1 
count if nvals
*** Number of unique IDs per bimester_redefined  **********
cap drop nvals
by `idvar' `timevar': gen nvals = _n == 1 
count if nvals
cap drop nvals

*** Number treated ***
count if !mi(cuat_since_switch) // treated 
uniquevals `idvar' if !mi(cuat_since_switch)

**********
** SAVE **
**********
save "$proc/ATM_use`sample'.dta", replace

*************
** WRAP UP **
*************
log close
exit
	