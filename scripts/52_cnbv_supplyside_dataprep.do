** SUPPLY SIDE DATA PREP
** Sean Higgins
** Created 05aug2015

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 52_cnbv_supplyside_dataprep
set linesize 200
cap log close
log using "$logs/`project'_`time'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

************
** LOCALS **
************
local dayspermonth = (365/12)
local nlags 12 // number of quarters of leads and lags

***************************************
** DATA: WHEN EACH LOCALITY SWITCHED **
***************************************
use "$proc/cards_mun.dta", clear
rename municipio cve_mun
tempfile mun_bimswitch
save `mun_bimswitch', replace

********************************************************
** DATA: BRANCHES, ATMs FOR BANCA MULTIPLE BY QUARTER **
********************************************************
// Note these data are in wide format; reshape to long below
local files : dir "$proc" files "bm_*.dta"
foreach file of local files {
	// parse out varname from `file'
	local re_var = regexm("`file'","_([a-zA-Z]*)_")
	local var = regexs(1) // e.g. "cajeros" for file bm_cajeros_month.dta
	
	use "$proc/`file'", clear
	reshape long v, i(cve_mun) j(yearmonth)
	rename v bm_`var'
	recode bm_`var' (missing = 0) // missing in original CNBV Excels indicates no branches/ATMs
	
	qui summ yearmonth 
	mydi "`file': `r(min)'", s(4) starchar("!")
	// only use if data exists from 200812 on (some vars begin at 201104 which is too late)
	if r(min)>=201104 continue // exit this iteration of loop
	drop edo nom_mun // unnecessary variables
	tempfile file`var'
	save `file`var'', replace
	local bm_processed_files `bm_processed_files' `file`var''
}
local i=0
foreach file of local bm_processed_files {
	local ++i
	
	if `i'==1 use `file', clear 
	else {
		merge 1:1 cve_mun yearmonth using `file', assert(match)
		drop _m
	}
}	

// SAVE
tempfile bm_sucursales
save `bm_sucursales', replace

**********************************************************
** DATA: BRANCHES, ATMs FOR BANCA DESARROLLO BY QUARTER **
**********************************************************
// Note already in long format from bd_sucursales.do
local files : dir "$proc" files "bd_*.dta"
foreach file of local files {
	// parse out varname from `file'
	local re_var = regexm("`file'","_([a-zA-Z]*)_")
	local var = regexs(1) // e.g. "cajeros" for file bm_cajeros_month.dta

	use "$proc/`file'", clear
	uniquevals cvelocalidad // Sean's user-written ado file
		// note that there are way less localities in the cajeros data set 
		// because not many development banks have cajeros relative to sucursales
		// (ex: Bansefi has ~500 sucursales but only 30 cajeros)
	foreach vv in cvelocalidad yearmonth year month {
		assert !mi(`vv')
	}
	recode totalgeneral-sociedad (missing = 0)
	
	// Make sure the totalgeneral variable (included in raw CNBV data) 
	//  really is the sum of #sucursales or #ATMs from each institution
	ds cvelocalidad totalgeneral yearmonth year month, not
	local sumvars = subinstr(`"`r(varlist)'"'," ","+",.) // "
	assert totalgeneral == `sumvars' // good to go
	
	rename totalgeneral bd_`var'
	rename bansefi bansefi_`var'

	// COLLAPSE TO MUNICIPALITY LEVEL (TO BE CONSISTENT WITH BANCA MULTIPLE DATA)
	gen cve_mun = real(substr(cvelocalidad,1,5))
	collapse (sum) bd_`var' bansefi_`var', by(cve_mun yearmonth)
	
	tempfile file`var'
	save `file`var'', replace
	local bd_processed_files `bd_processed_files' `file`var''
}
local i=0
foreach file of local bd_processed_files {
	local ++i
	
	if `i'==1 use `file', clear 
	else {
		merge 1:1 cve_mun yearmonth using `file'
		drop _m
	}
}	
tempfile bd_sucursales
save `bd_sucursales', replace

***********
** MERGE **
***********
use `bm_sucursales', clear
merge 1:1 cve_mun yearmonth using `bd_sucursales', assert(master match)
	// bm_sucursales has more municipalities because not every municipality has a development bank
drop _m
foreach x in cajeros sucursales {
	gen total_`x' = bm_`x' + bd_`x' // note bd_`x' is inclusive of bansefi_`x'
}
stringify cve_mun, digits(5) add("0")
merge m:1 cve_mun using `mun_bimswitch'
drop if _m==1 // not in wave 1, wave 2, or control
drop _m
gen bimswitch_year  = substr(bimswitch,1,4)
gen bimswitch_bim   = substr(bimswitch,5,2)
gen bimswitch_month = string(real(bimswitch_bim)*2) // second month of bimester
	// e.g. first month of bimester 1 is 1 (Jan), first month of bimester 2 is 3 (Mar)
gen bimswitch_fecha = bimswitch_month + " 1 " + bimswitch_year // 1 for first day of month
	// above two commands are because cards usually distributed around half way through bimester
gen bimswitch_date  = date(bimswitch_fecha,"MDY")
format bimswitch_date %td
tab bimswitch_date
replace bimswitch_date = bimswitch_date + 2*`dayspermonth' // 1 bimester delay according to Oportunidades
gen yearmonthday = string(yearmonth) + "01" // first day of month, which is the date given in the files
gen yearmonth_date = date(yearmonthday,"YMD")
format yearmonth_date %td
tab yearmonth_date
// Create leads and lags manually since there is a disconnect between quarters (CNBV data) and 
//  Lags test if expansion of ATMs and branches followed assignment of debit cards
//  Leads test if assignment of debit cards followed 
forval i=0/`nlags' { 
	gen has_card_L`i' = (bimswitch_date + 3*`i'*`dayspermonth' < yearmonth_date) // had it for at least 1 quarter
	gen switched_card_L`i' = (bimswitch_date + 3*`i'*`dayspermonth' < yearmonth_date) & (bimswitch_date + 3*`=`i'+1'*`dayspermonth' >= yearmonth_date)
	if `i'>0 gen switched_card_F`i' = (bimswitch_date > yearmonth_date + 3*`=`i'-1'*`dayspermonth') & (bimswitch_date < yearmonth_date + 3*`i'*`dayspermonth')
		// hasn't switched by period `i'-1 but switched in period `i'
	gen has_card_F`i' = (bimswitch_date < yearmonth_date + 3*`i'*`dayspermonth')
}

**********
** SAVE **
**********
save "$proc/cnbv_supply.dta", replace

*************
** WRAP UP **
*************
log close
exit
