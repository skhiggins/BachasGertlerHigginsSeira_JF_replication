** NUMBER OF WITHDRAWALS OVER CALENDAR TIME IN THE CONTROL GROUP
**  Pierre Bachas and Sean Higgins
**  Created 15April2016

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 117_withdrawals_control_graph
cap log close
local sample $sample 
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
	230001 /* CUOTA PLAN DE PENSIONES */
	990002 /* ABONOS VARIOS */
;

#delimit cr

**********
** DATA **
**********
use "$proc/transactions_redef_bim`sample'", clear // transaction level database,
merge m:1 integranteid using $proc/bim_switch_integrante.dta // Needed to Bring time of switch 	
keep if _merge == 3
drop _merge

mydi "Total transactions", stars(4) starchar("!")
count

// Use the codorigen to determine if bank or ATM transactions	
egen is_ATM = anymatch(codorigen), values(`ATM_list')
egen is_Bank = anymatch(codorigen), values(`Bank_list')
egen is_POS = anymatch(codorigen), values(`POS_list')
egen is_deposit = anymatch(codorigen), values(`deposit_list')

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
drop if importe==0

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
	by(integranteid date_opened sucadm bimester_redefined)
rename pos_deposit N_deposits
rename pos_withdrawal N_withdrawals
rename is_op_deposit N_Op_deposits
rename is_client_deposit N_client_deposits
foreach var of varlist N_* {
	tab `var'
}

sort integranteid bimester_redefined, stable
by integranteid bimester_redefined : assert _N==1 // no duplicates
describe

************************************************
///  WITHDRAWALS OVER TIME IN CONTROL
************************************************	
merge m:1 integranteid using "$proc/bim_switch_integrante.dta" // Needed to Bring time of switch 	
keep if _merge == 3
drop _merge

// BRING SUCURSAL
cap drop _merge
merge m:1 integranteid using "$proc/integrante_sucursal`sample'.dta"
keep if _merge == 3
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

// Sample selection: Keep only control 
drop if missing(bim_switch)
gen byte t = (bim_switch<=29)
keep if t == 0 

************************
// Count observations 
************************
*** Number of observations (transactions) **********
count 
*** Number of unique IDs  **********
by integranteid, sort: gen nvals = _n == 1 
count if nvals
*** Number of unique IDs per bimester_redefined  **********
cap drop nvals
by integranteid bimester_redefined, sort: gen nvals = _n == 1 
count if nvals
cap drop nvals
*** Total amount 
total N_withdrawals

// Regression 
reg N_withdrawals ibn.bimester_redefined, ///
	noconstant vce(cluster branch_clave_loc)

matrix B = r(table)
matrix list B

matrix results = J(29,5,.)  // 9 cuatr_since-switch from -9 to 5 = 15 periods, 7 variables of interest
mat list results

forval i=1/29 { 
	matrix results[`i',1] = `i' 
	matrix results[`i',2] = B[1,`i']
	matrix results[`i',3] = B[5,`i'] 
	matrix results[`i',4] = B[6,`i'] 
	matrix results[`i',5] = B[4,`i'] 
}

mat list results 

** Keep only Matrix to do graph
clear
svmat results , name(C)	

rename C1 bimester_redefined
rename C2 N_withdrawals
rename C3 rcap_lo
rename C4 rcap_hi
rename C5 p

label define bimester_redefined ///
 1 "Jan 07"  2 "Mar 07"  3 "May 07"  4 "Jul 07"  5 "Sep 07"  6 "Nov 07" ///
 7 "Jan 08"  8 "Mar 08"  9 "May 08" 10 "Jul 08" 11 "Sep 08" 12 "Nov 08" ///
13 "Jan 09" 14 "Mar 09"	15 "May 09" 16 "Jul 09" 17 "Sep 09" 18 "Nov 09" ///
19 "Jan 10" 20 "Mar 10"	21 "May 10" 22 "Jul 10" 23 "Sep 10" 24 "Nov 10" ///
25 "Jan 11" 26 "Mar 11"	27 "May 11" 28 "Jul 11" 29 "Sep 11" 

label values bimester_redefined bimester_redefined

**********************
** LOCALS for GRAPH **
**********************
graph_options, labsize(large) ///
	plot_margin(margin(sides)) ///
	graph_margin(margin(t=3)) ///
	ylabel_format(format(%2.1f)) ///
	x_angle(angle(vertical)) ///
	title_options(margin(b=2 t=0 l=0 r=0) color(black) span)

**********************
// GRAPH
**********************

local startbim=1
local endbim=29

#delimit ; 

graph twoway  
	(rarea rcap_hi rcap_lo bimester_redefined, color(orange*0.35))	
	(line N_withdrawals bimester_redefined, `control_line') ,	
	yscale(range(0 2)) 	 ytitle("") 
	ylabel(0(0.5)2, `ylabel_options') 
	xscale(range(`startbim' `endbim'))  xtitle("")
	xlabel(`startbim'(2)`endbim', `xlabel_options') 
	title("") 
	legend(off)
	`plotregion' `graphregion'
;

#delimit cr 

graph export "$graphs/timeline_withdrawals_control`sample'_`time'.eps", replace
	
*************
** WRAP UP **
*************
log close
exit
		