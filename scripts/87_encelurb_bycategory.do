// REGRESSIONS BY SPENDING CATEGORY

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 87_encelurb_bycategory
cap log close
set linesize 200
log using "$logs/`project'_`time'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

************
** LOCALS **
************
local randinf = 1
local N_perm = 2000
if c(matsize) < `N_perm' set matsize `N_perm' 
if c(maxvar) < 32767 set maxvar 32767

**********
** DATA **
**********
use "$proc/encel_forreg_bycategory.dta", clear // !data!

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
		transport
		services_mes 
;
#delimit cr

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
	foreach suf in "" "_1" "_5" {
		foreach pre in cons propinc {
			// expand locals
			local `pre'_vars_bl`suf'   ``pre'_vars_bl`suf'' `pre'_`var'`suf'_bl
			local `pre'_trends_bl`suf' ``pre'_trends_bl`suf'' d_`pre'_`var'`suf'_bl
		}
	}
}

foreach suf in "" "_1" "_5" {
	local durables_vars_bl`suf' cons_durables`suf'_bl
	local durables_trends_bl`suf' d_cons_durables`suf'_bl
	foreach var of varlist spent_durables? {
		local durables_vars_bl`suf' `durables_vars_bl`suf'' `var'_bl
		local durables_trends_bl`suf' `durables_trends_bl`suf'' d_`var'_bl
	}
}
local durables_spent_vars spent_durables_any_bl
local durables_spent_trend d_spent_durables_any_bl
foreach var of varlist spent_durables? {
	if "`var'"=="spent_durables7" continue
	local durables_spent_vars `durables_spent_vars'  `var'_bl
	local durables_spent_trend `durables_spent_trend' d_`var'
}

di "`outcomes_vars_bl_5' `outcomes_trends_bl_5'"

#delimit ;
local outcomelist_cats /* just the big categories */
	temptation 
	other_food
	non_durables
	educhealth 
	services_mes
;
#delimit cr

// Matrix for results:
//  1) Proportion of income spent on category by control
//  2) Absolute change in proportion of income
//  3) Percent change in proportion of income
//  4) Number of households
//  5) Number of observations
local N_cats = wordcount(`"`outcomelist_cats'"') // "

// Table
matrix results_table = J(`=`N_cats'*4', 5, .)
matrix colnames results_table = "control_mean" "beta" "relative" "N_hh" "N"

local row = 1
local w 5 // winsowrized at 5% level (preferred specification in consump results)

// Check how many obs there would be if no missing in `propinc_vars_bl_`w'' `propinc_trends_bl_`w''
xtreg totcons_5 DD04s i.year ///
	ib2002.year#c.(`X_bl' `outcomes_vars_bl_`w'' `outcomes_trends_bl_`w'') ///
	, fe vce(cluster localidad04)
di e(N)
count if totinc == 0 & e(sample)
di e(N) - r(N) 

foreach var of local outcomelist_cats {
	local col = 0
	mydi "`var'", stars(4)
	
	// Mean in control at baseline
	qui reg propinc_`var'_`w' if T04s==0 & year < 2009, vce(cluster localidad04)
	local control_mean = _b[_cons]
	di "mean: " _b[_cons]
	local ++col
	matrix results_table[`row', `col'] = _b[_cons] 
	matrix results_table[`=`row'+1', `col'] = _se[_cons]
	
	// Regression
	#delimit ;
	qui xtreg propinc_`var'_`w' DD04s i.year 
		ib2002.year#c.(
			`X_bl' `outcomes_vars_bl_`w'' `outcomes_trends_bl_`w'' 
			`propinc_vars_bl_`w'' `propinc_trends_bl_`w'' 
		)
		, fe vce(cluster localidad04)
	;
	#delimit cr
	local ++col
	matrix results_table[`row', `col'] = _b[DD04s]
	matrix results_table[`=`row'+1', `col'] = _se[DD04s]
	di _b[DD04s]
	di "(" _se[DD04s] ")"
	local teststat = abs(_b[DD04s]/_se[DD04s])
	local pvalue = 2*ttail(e(df_r), `teststat')
	matrix results_table[`=`row'+2', `col'] = `pvalue'
	di "[" `pvalue' "]"

	// Relative change
	// Mean in control at 2009
	qui summ propinc_`var'_`w' if T04s==0 & year == 2009, meanonly
	local control_mean = r(mean)
	local ++col
	di _b[DD04s]/`control_mean'
	matrix results_table[`row', `col'] = _b[DD04s]/`control_mean'
	di "(" _se[DD04s]/`control_mean' ")"
	matrix results_table[`=`row'+1', `col'] = _se[DD04s]/`control_mean'
	matrix results_table[`=`row'+2', `col'] = `pvalue' // doesn't change with rescaling

	// N
	local ++col
	di "N: " e(N)
	matrix results_table[`row', `col'] = e(N)
	
	// N hh
	local ++col
	di "N hh: " e(N_g)
	matrix results_table[`row', `col'] = e(N_g)
	
	
	if `randinf' {
		matrix results_permute = J(`N_perm', 1, .)
		
		_dots 0, title("Permutations") reps(`N_perm')
		forval i=1/`N_perm' {
			#delimit ;
			qui xtreg propinc_`var'_`w' DD04s`i' i.year 
				ib2002.year#c.(
					`X_bl' `outcomes_vars_bl_`w'' `outcomes_trends_bl_`w'' 
					`propinc_vars_bl_`w'' `propinc_trends_bl_`w'' 
				) 
				, fe vce(cluster localidad04)
			;
			#delimit cr
			matrix results_permute[`i', 1] = abs(_b[DD04s`i']/_se[DD04s`i'])
				
			_dots `i' 0
		}
		
		preserve
		clear
		svmat results_permute
		rename results_permute1 teststat_permute
		
		gen permuted_higher = (teststat_permute > `teststat')
		
		di "`teststat'"
		summ permuted_higher, meanonly
		matrix results_table[`=`row'+3', 2] = r(mean) // pvalue
		matrix results_table[`=`row'+3', 3] = r(mean) 
		restore
	}
	
	local row = `row' + 4 // for standard error, pvalue, randinf pvalue
} 

matlist results_table

// Save results to create table
preserve
clear
svmat results_table, names(col)
gen outcome = ""
local row = 1
foreach var of local outcomelist_cats {
	replace outcome = "`var'" in `row'/`=`row'+1'
	local ++row
	local ++row
}
save "$proc/encel_bycategory_results.dta", replace
restore

*************
** WRAP UP **
*************
log close
exit
