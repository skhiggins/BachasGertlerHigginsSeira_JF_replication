** CALCULATE BIMESTER OF SWITCH
**  Pierre Bachas and Sean Higgins

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 06_bansefi_bimswitch
cap log close
set linesize 200
log using "$logs/`project'_`time'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

************
** LOCALS **
************
local startyear 2007
local endyear   2015
local retiro_op STR79OBB //	SERVICIO DE RETIRO MASIVO                          
local deposito_op /// According to Bansefi, the following define Oportunidades deposits:
	STR80OBB /// SERVICIO DE REEMBOLSO MASIVO                       
	STR83OBB /// SERVICIO DE REEMBOLSO MASIVO BIMESTRE 1           
	STR84OBB /// SERVICIO DE REEMBOLSO MASIVO BIMESTRE 2           
	STR85OBB /// SERVICIO DE REEMBOLSO MASIVO BIMESTRE 3           
	STR86OBB /// SERVICIO DE REEMBOLSO MASIVO BIMESTRE 4           
	STR87OBB /// SERVICIO DE REEMBOLSO MASIVO BIMESTRE 5           
	STR88OBB //  SERVICIO DE REEMBOLSO MASIVO BIMESTRE 6 
local i=0	
foreach x of local deposito_op {
	local ++i
	if `i'==1 local comma ""
	else local comma ","
	local deposito_op_c `"`deposito_op_c'`comma'"`x'""'
	di "
}	
di `"`deposito_op_c'"' // "
local min_op_deposit = 300

local make_sample = 1

**********
** DATA **
**********
use "$proc/DatosGenerales.dta", clear
mydi "PROD VEN" , s(4)
tab prod_ven if idarchivo==1
gen str2 type = ""
replace type = "CA" if inlist(substr(prod_ven,1,4),"V002","V003")
	// cuentahorro
replace type = "DC" if substr(prod_ven,1,4)=="V008"
	// debicuenta
assert !missing(prod_ven)
tempfile tomerge
save `tomerge'

forval year=`startyear'/`endyear' {
	if `year'==`startyear' {
		use $proc/MOV`year'.dta, clear
	}
	else {
		append using $proc/MOV`year'.dta
	}
}

merge m:1 cuenta using `tomerge'
tab idarchivo if _merge==1
tab idarchivo if _merge==2
keep if idarchivo==1 // Sample for ATM paper (==2 is lottery paper)
gen byte is_op_deposit = (naturaleza=="H" & ///
	importe>`min_op_deposit' & ///
	inlist(cod_tx,`deposito_op_c'))
gen date = date(fecha_contable,"YMD")
format date %td
gen year = year(date)
tab year if _merge==1
tab year if _merge==2
gen month = month(date)
gen bimester = ceil(month/2) // 1 to 6
gen bimester_count = (year - `startyear')*6 + bimester
	// 1,...,6,7,...
keep is_op_deposit type integranteid cuenta year bimester bimester_count
collapse (sum) N_op_deposits = is_op_deposit, ///
	by(type integranteid cuenta year bimester bimester_count)
keep if type=="CA" // cuentahorro accounts
tab N_op_deposits
	// note bimesters with no Op deposits may be missing 
	//  (if no transactions at all that bimester)
drop if N_op_deposits==0
sort cuenta, stable
by cuenta : gen last_deposit = bimester_count[_N]
	// last bimester with positive number of Op deposits for that cuenta
by cuenta : gen tag = (_n==1)
gen bim_switch = last_deposit + 1
tab bim_switch if tag

keep if tag==1
drop year bimester bimester_count N_op_deposits last_deposit tag
	// these variables no longer make sense once collapsed to
	//  account-level data set
	
bimestrify, startyear(2007) alreadybim(bim_switch) // !user! 
tab bim_switch
replace bim_switch = . if bim_switch==48 // very end of 8 years of data

**********
** SAVE **
**********
save "$proc/bim_switch_cuentahorro.dta", replace
	// note this one is by cuenta but only includes the 
	//  cuentahorro (i.e. the pre-switch account)

// By integranteid:
use "$proc/DatosGenerales.dta", clear
merge m:1 integranteid using "$proc/bim_switch_cuentahorro.dta"
sort integranteid cuenta 
by integranteid : drop if _n>1 // duplicates drop 
count
count if _merge==3
drop _merge
keep integranteid bim_switch
save "$proc/bim_switch_integrante.dta", replace
	
if `make_sample' {
	merge m:1 integranteid using "$proc/DatosGenerales_sample1.dta", ///
		keepusing(integranteid)
	tab _merge 
	keep if _merge==3
	drop _merge
	count
	describe
	save "$proc/bim_switch_integrante_sample1.dta", replace
}

*************
** WRAP UP **
*************
log close
exit

