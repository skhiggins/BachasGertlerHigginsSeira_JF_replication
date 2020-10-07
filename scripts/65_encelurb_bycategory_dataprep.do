// REGRESSIONS BY SPENDING CATEGORY
//  Sean Higgins

*******************
** PRELIMINARIES **
*******************
if c(maxvar) < 32767 set maxvar 32767
if c(matsize) < 5000 set matsize 5000
include "$scripts/encelurb_dataprep_preliminary.doh" // !include!

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 65_encelurb_bycategory_dataprep
cap log close
set linesize 200
log using "$logs/`project'_`time'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

local weeks_per_month = 30/7 // because they don't actually ask about last month, they ask
	// "en los últimos 30 días"

**********
** DATA **
**********
use "$proc/encel_forreg_withperm.dta", clear // !data!

recode cons_* (. = 0)

#delimit ;

local X
 	trabajo_jefe 
 	escolaridad_jefe escolaridad_jefe_sq 
 	edad_jefe        edad_jefe_sq   
	cuenta_bancaria 
	p_derechohabiencia 
 	p_analfabeta_15_
	p_no_asiste_6_14
 	p_basica_inc_15_ 
	d_menos9_15_29   
	piso_tierra
 	sin_sanitario  
	sin_agua
	sin_drenaje 
	oc_por_cuarto  
;

gen cons_eatout = expend_eatout*`weeks_per_month';
gen cons_temptation = 
	cons_alcohol + 
	cons_tobacco + 
	cons_sugar   + 
	cons_soda    + 
	cons_sweets  + 
	cons_junk    + 
	cons_oil 
;

gen cons_other_food = 
	cons_meat + 
	cons_dairy + 
	cons_fruit + 
	cons_veg + 
	cons_cereals + 
	cons_eatout
;

gen cons_non_durables = 
	cons_non_durables_sem +  
	cons_non_durables_mes + 
	cons_non_durables_tri 
;

gen cons_educhealth = 
	cons_educ +
	cons_health 
; // cons_transport_educ?;

gen cons_services = cons_services_mes + cons_transport; // cons_services_tri;

gen spent_durables_any = max(
	spent_durables1, 
	spent_durables2, 
	spent_durables3, 
	spent_durables4, 
	spent_durables5, 
	spent_durables6
)
;

local outcomelist 
	temptation 
		alcohol
		tobacco
		sugar  
		soda   
		sweets 
		junk   
		oil 
	other_food
		meat
		dairy 
		veg
		fruit
		cereals
		eatout
	non_durables
		non_durables_sem
		non_durables_mes
		non_durables_tri
	durables 
		durables2
		durables3
		durables4
		durables5
		durables6
	other_durables
	educhealth
		educ
		health
	services 
		services_mes
		transport  
;
#delimit cr

foreach var of local outcomelist {
	di "`var'" 
	count if mi(cons_`var')
}

rename cons_other_durables_tri cons_other_durables // length issue

local outcomes totcons totinc cons_durables z_assetindex
foreach outcome of local outcomes {
	foreach w in 1 5 {
		local outcomes_vars_`w' `outcomes_vars_`w'' `outcome'_`w'
		local outcomes_trends_`w' `outcomes_trends_`w'' d_`outcome'_`w'
	}
}

foreach var of local X {
	confirm var `var'_bl
	local X_bl `X_bl' `var'_bl
}

foreach w in 1 5 {
	foreach var of local outcomes_vars_`w' {
		local outcomes_vars_bl_`w' `outcomes_vars_bl_`w'' `var'_bl
	}
}

foreach w in 1 5 {
	foreach var of local outcomes_trends_`w' {
		local outcomes_trends_bl_`w' `outcomes_trends_bl_`w'' `var'_bl
	}
}

foreach var of local outcomelist {
	gen propinc_`var' = cons_`var'/totinc
}

foreach w in 1 5 {
	foreach var of local outcomelist {
		cap drop cons_`var'_`w' // cap drop since recode cons_* (. = 0) above
		winsify cons_`var', winsor(`w') ///
			treatment(T04s) treatment_levels(0 1) ///
			timevar(year) timevar_levels(2002 2003 2004 2009) ///
			gen(cons_`var'_`w') highonly
		cap drop propinc_`var'_`w'
		winsify propinc_`var', winsor(`w') ///
			treatment(T04s) treatment_levels(0 1) ///
			timevar(year) timevar_levels(2002 2003 2004 2009) ///
			gen(propinc_`var'_`w') highonly
	}
}

foreach var of local outcomelist {
	foreach pre in cons propinc {
		cap drop `pre'_`var'?? `pre'_`var'_bl
		baselinify `pre'_`var'
		
		foreach w in 1 5 {
			cap drop `pre'_`var'_`w'?? `pre'_`var'_`w'_bl
			baselinify `pre'_`var'_`w'
		}
	}
}

xtset
local _panelvar `r(panelvar)'
local _timevar `r(timevar)'
foreach var of local outcomelist {
	foreach suf in "" "_1" "_5" {
		foreach pre in cons propinc { 
			sort `_panelvar' `_timevar', stable
			cap drop d_`pre'_`var'`suf'
			by folio_num : gen d_`pre'_`var'`suf' = `pre'_`var'`suf' - `pre'_`var'`suf'[_n - 1] if _n != 1
		
			cap drop d_`pre'_`var'`suf'?? d_`pre'_`var'`suf'_bl
			baselinify d_`pre'_`var'`suf'
			
			// expand locals
			local `pre'_vars_bl`suf'   ``pre'_vars_bl`suf'' `pre'_`var'`suf'_bl
			local `pre'_trends_bl`suf' ``pre'_trends_bl`suf'' d_`pre'_`var'`suf'_bl
		}
	}
}

foreach var of varlist spent* { // durables
	baselinify `var'
	sort `_panelvar' `_timevar', stable
	by folio_num : gen d_`var' = `var' - `var'[_n - 1] if _n != 1
	baselinify d_`var'
}
confirm var d_spent_durables_any_bl

// Make sure the locals generated correctly
di "`outcomes_vars_bl_5' `outcomes_trends_bl_5'"

**********
** SAVE **
**********
compress
save "$proc/encel_forreg_bycategory.dta", replace

*************
** WRAP UP **
*************
log close
exit
