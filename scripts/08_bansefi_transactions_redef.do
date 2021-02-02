** TRANSACTIONS DATA WITH BIMESTER AND REDEFINED PERIODS
**  (where redefined periods refers to coding a shifted deposit from 
**   period t to period t-1 as happening in period t; also codes any transactions
**   after that date as period t) 
**  Pierre Bachas and Sean Higgins
**  Created 02mar2016

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 08_bansefi_transactions_redef
cap log close
set linesize 200
log using "$logs/`project'_`time'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

************
** LOCALS **
************
local sample $sample

// Control center
local make_sample = 1 // 1 to make 1% sample at end, 0 otherwise
local startyear = 2007
local endyear   = 2011
local fast = 0 // 0 for full output, 1 to run faster omitting some output like tabulations

local dit noisily display as text in smcl

local retiro_op STR79OBB //	SERVICIO DE RETIRO MASIVO                          
local deposito_op /// According to Bansefi, the following define Oportunidades deposits:
	STR80OBB /// SERVICIO DE REEMBOLSO MASIVO                       
	STR83OBB /// SERVICIO DE REEMBOLSO MASIVO bimester 1           
	STR84OBB /// SERVICIO DE REEMBOLSO MASIVO bimester 2           
	STR85OBB /// SERVICIO DE REEMBOLSO MASIVO bimester 3           
	STR86OBB /// SERVICIO DE REEMBOLSO MASIVO bimester 4           
	STR87OBB /// SERVICIO DE REEMBOLSO MASIVO bimester 5           
	STR88OBB //  SERVICIO DE REEMBOLSO MASIVO bimester 6 
local i=0	
foreach x of local deposito_op {
	local ++i
	if `i'==1 local comma ""
	else local comma ","
	local deposito_op_c `"`deposito_op_c'`comma'"`x'""' // "
}	
di `"`deposito_op_c'"' // "
local x = 300 // lower bound cut-off for Op deposit

**********
** DATA **
**********
// Data set of each account to merge
use "$proc/DatosGenerales`sample'.dta", clear

// Date account opened
gen date_opened = date(fecalta,"YMD")
replace date_opened = . if date_opened == date("01jan1990","DMY")
	// this is how they mark missing values for this variable
format date_opened %td
	
// Make sure it's right for those who switched (use date first account opened, not date of switch)
sort integranteid date_opened
tempvar date_opened_min
by integranteid : egen `date_opened_min' = min(date_opened)
replace date_opened = `date_opened_min'

tempfile tomerge
save `tomerge', replace

// Load in transactions data, assign 0s for accounts with no transaction in a particular bimester
forval year=`startyear'/`endyear' {
	noisily mydi "`year'", s(4)
	use "$proc/MOV`year'`sample'.dta", clear
	drop if cod_tx=="LIQ11OBB" // interest payments (drop so we don't count them as deposits)
	gen date = date(fecha_contable, "YMD")
	assert !missing(date) 
	format date %td
	gen month = month(date)
	gen bimester_in_year = ceil(month/2) // 1 through 6
	tab bimester_in_year
	gen year = year(date)
	assert year==`year' // to make sure nothing weird is going on with years
	
	merge m:1 cuenta using `tomerge'
		// no keepusing() so this also merges the variables that are in Datos Generales
	keep if _merge==3 // non-match are accounts without any transactions that year
	drop _merge
	keep if idarchivo==1 // this is how Bansefi marked the ATM accounts
		// (since data set also includes Lottery accounts, and other accounts for 
		//  ATM and Lottery sample)
	assert bimester_in_year<=6
	assert !missing(year)

	// Dummy for Oportunidades deposits
	gen is_op_deposit = (naturaleza=="H" & importe>`x' & inlist(cod_tx,`deposito_op_c'))
	gen is_client_deposit = (naturaleza=="H" & !inlist(cod_tx,`deposito_op_c'))
	
	gen pos_deposit    = (importe>0 & naturaleza=="H") // note pos means positive, not POS terminal 
	gen pos_withdrawal = (importe>0 & naturaleza=="D")
		
	tempfile transactions`year'
	save `transactions`year'', replace
}

************
** APPEND **
************
// transactions level data set with all years (2007-2011) together:
forval year=`startyear'/`endyear' {
	if `year'==`startyear' use `transactions`year''
	else append using `transactions`year''
}

bimestrify , startyear(`startyear') bim(bimester_in_year) year(year) gen(bimester)
	// This program is defined in server_header.doh
	// NOTE: bimester_in_year is 1,...,6 within each year while bimester is 1,...,7,...
	//  (i.e., if `startyear' is 2007, Jan-Feb 2008 has bimester_in_year==1 and bimester==7)
	
tab bimester

// Redefined: if Oportunidades payment was shifted to end of previous period,
//  recode that and subsequent transactions in the period as the following period
//  1. Create variable that has a string of the last month of the bimester
decode bimester, gen(__bim_string) // use __ prefix to drop these vars later
if !(`fast') tab __bim_string
gen __post_hyphen = strpos(__bim_string,"-") + 1
gen __end_month   = substr(__bim_string,__post_hyphen,3)
if !(`fast') tab __end_month // it worked
//  2. Create cut-off date for switch: 16th day of last month of 4-month period
sort bimester
by bimester: egen __end_year = max(year) // for periods that span 2 calendar years
	// this was from when we were doing redefine at cuatrimestre level; 
	// for bimester level we could have just done gen __end_year = year 
	// and will get the same result
gen __cut_off = __end_month + " 16 " + string(__end_year) // can concatenate strings like this
	// shifts appear to always be to the second half of previous month or later
	// so cut_off is the 16th day of last month of period
gen __cut_off_num = date(__cut_off,"MDY") // numeric %td version of date
format __cut_off_num %td
if !(`fast') tab __cut_off_num bimester // it worked
//  3. Marker for if there is a shifted payment, and date and amount of shifted payment
gen __op_deposit_shifted = (is_op_deposit==1) & (date >= __cut_off_num)
gen __op_deposit_shifted_date = date if __op_deposit_shifted==1 // missing otherwise
//  4. For all transactions in an account x period pair that has a shifted 
//      Oportunidades payment, marker dummy indicated existence of shifted payment,
//      plus date of shifted payment
sort integranteid bimester
by integranteid bimester : egen __has_op_deposit_shifted = max(__op_deposit_shifted)
	// so __has_op_deposit_shifted == 1 for all types of transactions within an account 
	//  and 4-month period 
by integranteid bimester : egen shift_date = min(__op_deposit_shifted_date)
	// use min() in case there are two payments in last two weeks of period 
	//  for whatever reason, use the first of the two
format shift_date %td
tab shift_date
gen __importe_shifted = importe if is_op_deposit==1 & date==shift_date
by integranteid bimester : egen importe_shifted = max(__importe_shifted)
//  5. Create redefined period if the account has a shifted Oportunidades payment:
//      all transactions happening after the date of the shifted payment are recoded 
//      as next period.
gen bimester_redefined = bimester
gen year_redefined = year
replace bimester_redefined = bimester + 1 if ///
	(__has_op_deposit_shifted == 1) & (date >= shift_date)
replace year_redefined = year + 1 if ///
	(mod(bimester_redefined,6)==1) & (mod(bimester,6)==0)
	// i.e. if the original bimester is the 6th of the year and bimester_redefined
	//  is 1st of year
label values bimester_redefined bimes
label var bimester_redefined "Redefined `: var label bimester'"
//  6. Drop temporary variables
drop __*

tab shift_date

**********
** SAVE **
**********
describe
save "$proc/transactions_redef_bim`sample'.dta", replace // transaction level database,
	// with original bimester variable and bimester_redefined
	
if `make_sample' {
	preserve
	merge m:1 integranteid using "$proc/DatosGenerales_sample1.dta", keep(match)
		// keep(match) automatically selects only the 1% sample
		// DatosGenerales_sample1 is a 1% sample of accounts from 7_make_sample.do
	drop _merge 
	save "$proc/transactions_redef_bim_sample1.dta", replace
	restore
}

// Oportunidades deposits only //! CHECK IF DEPRECATED
preserve
keep if is_op_deposit
save "$proc/OpDeposits_redef_bim`sample'.dta", replace // transaction level database,
	// with original bimester variable and bimester_redefined
	
if `make_sample' {
	merge m:1 integranteid using "$proc/DatosGenerales_sample1.dta", keep(match)
		// keep(match) automatically selects only the 1% sample
		// DatosGenerales_sample1 is a 1% sample of accounts from 7_make_sample.do
	drop _merge 
	save "$proc/OpDeposits_redef_bim_sample1.dta", replace
}
restore

****************************
** APPEND, COLLAPSE, SAVE **
****************************
// Data set with integranteid, bimester, switch_date
//  to merge in with the mechanical effect data 
//  (so that we can pick up the part of the mechanical effect
//  that occurs when there's a shifted payment) Aug 3, 2017 
preserve 
foreach var of varlist importe_shifted shift_date {
	by integranteid bimester : assert `var'==`var'[_N]
		// make sure `var' is constant within integranteid bimester
}
keep integranteid bimester shift_date importe_shifted
by integranteid bimester: drop if _n>1
rename bimester bimester_for_merge 
save "$proc/shift_dates.dta", replace

if `make_sample' {
	merge m:1 integranteid using "$proc/DatosGenerales_sample1.dta", ///
		keepusing(integranteid)
	tab _merge 
	keep if _merge==3
	drop _merge
	count
	describe
	save "$proc/shift_dates_sample1.dta", replace
}	
restore

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
by integranteid : gen sucursal = sucadm[1] // since in very rare cases the administering branch
	// changes during the period, set the sucursal variable as the one corresponding to the 
	// earliest transaction in the account
// make sure all integranteid have same date_opened, sucursal
foreach var of varlist date_opened sucursal {
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
	by(integranteid date_opened sucursal bimester_redefined)
rename pos_deposit N_deposits
rename pos_withdrawal N_withdrawals
rename is_op_deposit N_Op_deposits
rename is_client_deposit N_client_deposits
foreach var of varlist N_* {
	tab `var'
}

**********
** SAVE **
**********
sort integranteid bimester_redefined, stable
by integranteid bimester_redefined : assert _N==1 // no duplicates
describe
save "$proc/account_bimredef_transactions.dta", replace // by original bimester timing
	
if `make_sample' {
	merge m:1 integranteid using "$proc/DatosGenerales_sample1.dta", ///
		keepusing(integranteid)
	tab _merge 
	keep if _merge==3
	drop _merge
	count
	describe
	save "$proc/account_bimredef_transactions_sample1.dta", replace
}	
	
*************
** WRAP UP **
*************
cap log close
exit

