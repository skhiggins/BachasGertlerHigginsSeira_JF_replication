** PREPARE DATA FROM PAYMENT METHODS SURVEY
**  Written by Pierre Bachas and Sean Higgins
**  created December 2014, last edited 8dec2019

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 75_medios_de_pago_dataprep
cap log close
set linesize 200
log using "$logs/`project'_`time'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

*******************
** PRELIMINARIES **
*******************
// MERGE WITH LOCALITY/MUNICIPALITY-LEVEL VARS
//  Note: some of the other data sources don't have all the localities
//   or municipalities, so to keep the sample the same once adding these controls,
//   create a dummy variable denoting if it doesn't merge, then convert the 
//   missing to 0 and include the dummary variable as a control.
cap program drop merge_on
program define merge_on
	syntax varname using [if/], exists(string) controls(string)
	local varname `varlist' 
	
	merge m:1 `varname' `using', keepusing(`controls')
	
	if "`if'"!="" {
		local _if "if `if'"
		local and_if "& `if'"
	}
	
	gen `exists' = 0
	replace `exists' = 1 if _merge == 3
	assert !missing(`exists') if _merge == 3
	foreach var of varlist `controls' {
		replace `var' = 0 if `exists' == 0
	}			
	drop if _merge == 2
	drop _merge
	tab `exists' `_if'
	tab localidad if `exists' == 0 `and_if'
	uniquevals localidad if `exists' == 0 `and_if' 
end

**********
** DATA **
**********
use "$data/Medios_de_Pago/medios_pago_titular_beneficiarios.dta", clear
	// raw data from Prospera Medios de Pago survey

count // 5381
describe

// Keep Sample of DebiCuenta (debit card) users
keep if t325 == 1 
	// 1 [N=1641] Tarjeta que pude usarse en cajeros y autoservicios (débito) 
	// 2 [N=3715] Tarjeta con huella (prepagada)
	// 3 [N=  25] Otra (especifique) // note I made sure none of these descriptions (t325es) are tarjeta de debito  
count // 1641

** LOCALIDAD & MUNICIPIO 
gen localidad = substr(folio, 1, 9)
gen municipio = substr(folio, 1, 5)

// As a double check
stringify entidad, digits(2) gen(ent)
stringify munici, digits(3) gen(mun)
stringify locali, digits(4) gen(loc)
gen municipio2 = ent + mun
gen localidad2 = ent + mun + loc
assert municipio == municipio2
assert localidad == localidad2
drop ent mun loc municipio2 localidad2

// Time with card
tab t4a01a  // Years they have the card 
tab t4a01a, nol  // make sure "No sabe/no responde" coded as they say
tab t4a01b  // Month they have the card 
tab t4a01b, nol  // make sure "No sabe/no responde" coded as they say
drop if mi(t4a01a) // added by Sean; some weren't asked part IV of the survey so they have missing for all vars

count // 1617
tab t4a01a if t4a01b==99 // see if some where they reported years but not months; result: no
replace t4a01a=. if t4a01a==9
replace t4a01b=. if t4a01b==99 
gen months_card = t4a01a*12+t4a01b
sum months_card, d
** histogram months_card, discrete // look at distribution 

// t4a05 Hard to use ATM
** Code up open-ended responses to t4a05
** (because long strings in .sav files get cut off in Stata, opened it in R; 
** see mediospago_especificar.R for the full answers that the below excerpts come from)
#delimit ;
local hard_use /* corresponds to response 3 Es difícil utilizar el cajero */
	`"
	"NO SABE CONSULTAR EL SALDO"
	"TIENE QUE PEDIR AYUDA"
	"SI NO FUERA"
	"NO LA SABE UTILIZR"
	"NO SABIA UTILIZAR"
	"NO SABE UTILIZAR"
	"LA HIJA DE LA SRA"
	"SE LE DIFICULTA"
	"LA TITULAR NO ACUDE"
	"'
;
local no_entrego /* corresponds to response 4 El cajero no entregó el dinero */
	`"
	"NO APARECIA"
	"EL CAJERO NO LE RECONOCE"
	"MARCO MAL UN BOTON"
	"TIENEN PROBLEMAS PARA QUE LOS CAJEROS"
	"EL CAJERO NO LEE"
	"EL CAJERO AUTOMATICO QUE UTILIZA"
	"LOS CAJEROS EN OCASIONES"
	"NO RECONOCE"
	"ATENIDO PROBLEMAS"
	"NO LE DABA LECTURA"
	"TARDA EN LEER"
	"LO LEE"
	"NO LEE"
	"EL CAJERO LE DICE QUE NO"
	"RECHAZA LA TARJETA"
	"NO LE HA LLEGADO"
	"SE BLOQUEA"
	"NO HACEPTA LA TARGETA"
	"'
;
#delimit cr
gen hard_use_ATM = 0
replace hard_use_ATM = 1 if t4a05a==3 | t4a05b==3 | t4a05c==3
foreach reason in `hard_use' `no_entrego' {
	count if strpos(t4a05es1,"`reason'")
	assert r(N)>0 // make sure didn't introduce typo or it's not getting cut off by Stata
	replace hard_use_ATM = 1 if strpos(t4a05es1,"`reason'")
}
// note only 2 responses to t4a05es2 and none for hard_use or no_entrego; no responses to t4a05es3

// Does someone help you use the ATM?
tab t4a07b
gen byte help_ATM = (t4a07b==1)
replace help_ATM = . if t4a07b==3 // No contestó

// Number of withdrawals
tab t4a08
tab t4a01a t4a08
replace t4a08 = . if t4a08==99
rename t4a08 n_withdrawals

// Number of times checked balance
tab t4a10
tab t4a01a t4a10
replace t4a10 = . if t4a10==99
rename t4a10 check_balance

// Number of times checked balance without withdrawing
gen check_nowithdrawal = check_balance - n_withdrawals
tab check_nowithdrawal
replace check_nowithdrawal = 0 if check_nowithdrawal<0 

// Convert from bimester to 4-month period (for consistency with admin data results)
replace check_balance = check_balance*2
replace check_nowithdrawal = check_nowithdrawal*2
	
// Times used to pay in store 
tab t4a18
tab t4a01a t4a18
replace t4a18=. if t4a18==99

gen total_use = t4a18 + n_withdrawals // withdrawals + store payment

// Amount paid in store
sum t4a20, d
replace t4a20 = 0 if t4a20 == .
replace t4a20 = . if t4a20 == 9999

// t4a34 Knows PIN number
gen knows_PIN = (t4a34==1)
replace knows_PIN = . if t4a34==9 // No sabe

// Dummy for having card less or more than median time
summ months_card, de
gen card_less = (months_card<r(p50)) // median split

gen fees_check = t4a14 
replace fees_check = . if t4a14 == 99 
sum fees_check, d

gen fees_withdraw = t4a13
replace fees_withdraw = . if t4a13 == 99 
sum fees_withdraw, d

// t303 Married
gen married = (t303==1 | t303==2)

** Male
gen male = (t302==1)

** Education level
rename t311a nivel
rename t311b grado
** Niveles:
	** 0 Ninguno
	** 1 Kinder o preescolar
	** 2 Primaria
	** 3 Secundaria
	** 4 Preparatoria o Bachillerato
	** 5 Normal básica
	** 6 Carrera técnica o Comercial con primaria completa
	** 7 Carrera técnica o comercial con secundaria completa
	** 8 Carrera técnica o comercial con preparatoria completa
	** 9 Profesional
	** 10 Posgrado (Maestría o Doctorado)
	** 11 Ninguno

gen escolaridad = 0
replace grado=4 if (nivel==5 | nivel==6 | nivel==7) & (grado==5 | grado==9)                 
	// >=5 años en normal/profesional: set to 4 //
tab nivel grado
replace escolaridad= 0          if nivel==1 | nivel==11 | missing(nivel)
	** Note t311 gets skipped if they are illiterate, so add 0s for missing
replace escolaridad=     grado  if nivel==2				//Primaria//
replace escolaridad= 6 + grado  if nivel==3 | nivel==6	//Secundaria//
replace escolaridad= 9 + grado  if nivel==4 | nivel==7	//Prepa//
replace escolaridad= 12+ grado  if nivel==5 | nivel==8 | nivel==9 //Normal/Licenciatura/Professional//
replace escolaridad= 16+ grado  if nivel==10 //Posgrado//

*****************************************
** MERGE WITH LOCALITIY LEVEL CONTROLS
*****************************************		
// Log number of POS terminals
merge_on localidad using "$proc/bdu_baseline.dta", ///
	exists(data_POS) controls(log_pos) 
	// 96% have `exists' == 1
	// 2 localities with `exists' == 0

// Bansefi data on savings and transactions 
merge_on localidad using "$proc/bansefi_baseline_loc.dta", ///
	exists(data_bansefi) controls(N_withdrawals net_savings_ind_0 log_net_savings_ind_0)
	// 70% have `exists' == 1
	// 13 localities with `exists' == 0
	
// CNBV data on branches, ATMs, cards
merge_on municipio using "$proc/cnbv_baseline_mun.dta", ///
	exists(data_cnbv) controls(log_branch_number log_atm_number log_cards_all)
	// 92% have `exists' == 1
	// 4 localities with `exists' == 0

// Price data from micro-CPI
merge_on municipio using "$proc/cpix_baseline_mun.dta", ///
	exists(data_cpix) controls(log_precio)
	// 58% have `exists' == 1
	// 20 localities with `exists' == 0

// Wage data from ENOE
merge_on municipio using "$proc/enoe_baseline_mun.dta", ///
	exists(data_enoe) controls(log_wage)
	// 98% have `exists' == 1
	// 1 locality with `exists' == 0

**********
** SAVE **
**********
save "$proc/medios_de_pago.dta", replace

*************
** WRAP UP **
*************
log close
exit
