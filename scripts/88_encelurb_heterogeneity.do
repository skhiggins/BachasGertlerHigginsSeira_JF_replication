** HETEROGENEITY BY BARGAINING POWER

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 88_encelurb_heterogeneity
cap log close
set linesize 200
log using "$logs/`project'_`time'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

************
** LOCALS **
************
// Define control variables
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
#delimit cr
local outcomes totcons totinc cons_durables z_assetindex
foreach outcome of local outcomes {
	foreach w in 1 5 {
		local outcomes_vars_`w' `outcomes_vars_`w'' `outcome'_`w'
		local outcomes_trends_`w' `outcomes_trends_`w'' d_`outcome'_`w'
	}
}

foreach var of local X {
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

**********
** DATA **
**********
use "$proc/encel_forreg_bycategory.dta", clear // !data!

local restrict "if has_other_male_adult == 1" 
	// beneficiaries who have a partner or other male adult in the household

foreach var of varlist female?? {
	// Z-score version for Kling et al average 
	myzscore `var' `restrict', gen(`var'_z)
}
** Average the standardized variables, as in Kling et al (2007)
gen female_kling_bl = (female01_z + female02_z + female03_z + female04_z + female08_z)/5 ///
	`restrict'
	// note questions 5, 6, 7 are about what additional income to head and spouse is spent on;
	//  not bargaining power
	// That's why this is average from questions 1, 2, 3, 4, and 8
myzscore female_kling_bl `restrict', replace // so that interpret as 1sd change
_pctile female_kling_bl `restrict', n(100)
gen byte lo_female_kling_bl = (female_kling_bl < r(r50)) `restrict' & !missing(female_kling_bl)
	// negative baseline bargaining power (note it's a normalized var with mean 0, sd 1
	//  from myzscore above)

// Only for 2002 because that was the only pre-treatment survey wave that had it;
xtset
sort `r(panelvar)' `r(timevar)'
foreach var of varlist *female* {
	by folio_num: replace `var' = `var'[1] // first obs within hh is 2002
	by folio_num: replace `var' = `var'[1]
}

local het_var "i.lo_female_kling_bl"
local pull_het_var = subinstr("`het_var'", "i.", "1.", .)
local bigrow = 0
foreach var in totcons totinc z_assetindex {
	matrix `var' = J(8, 4, .)
	local col = 0
	
	// Specifications for columns 1-3:
	foreach w in "" "_1" "_5" {
		local row = 0
		xtreg `var'`w' i.(DD04s year)##`het_var' `restrict', ///
			fe vce(cluster localidad04)
		local ++col
		local ++row
		matrix `var'[`row', `col'] = _b[1.DD04s]
		local ++row
		matrix `var'[`row', `col'] = _se[1.DD04s]
		local ++row
		matrix `var'[`row', `col'] = 2*ttail(e(df_r), ///
			abs(_b[1.DD04s]/_se[1.DD04s])) // pvalue
		local ++row
		matrix `var'[`row', `col'] = _b[1.DD04s#`pull_het_var']
		local ++row
		matrix `var'[`row', `col'] = _se[1.DD04s#`pull_het_var']
		local ++row
		matrix `var'[`row', `col'] = 2*ttail(e(df_r), ///
			abs(_b[1.DD04s#`pull_het_var']/_se[1.DD04s#`pull_het_var'])) // pvalue
		
		// Number of observations
		local ++row
		matrix `var'[`row', `col'] = e(N_g) // number of households
		local ++row
		matrix `var'[`row', `col'] = e(N) // number of observations
	}
	
	// Specification for column 4
	//  since this one has smaller samle; redefine the median within reg sample
	local row = 0
	#delimit ;
	xtreg `var'_5 i.(DD04s year)##`het_var' 
		ib2002.year#c.(`X_bl' `outcomes_vars_bl_5' `outcomes_trends_bl_5')
		`restrict', 
		fe cluster(localidad04)
	;
	#delimit cr
	local ++col
	local ++row
	matrix `var'[`row', `col'] = _b[1.DD04s]
	local ++row
	matrix `var'[`row', `col'] = _se[1.DD04s]
	local ++row
	matrix `var'[`row', `col'] = 2*ttail(e(df_r), ///
		abs(_b[1.DD04s]/_se[1.DD04s])) // pvalue
	local ++row
	matrix `var'[`row', `col'] = _b[1.DD04s#`pull_het_var']
	local ++row
	matrix `var'[`row', `col'] = _se[1.DD04s#`pull_het_var']
	local ++row
	matrix `var'[`row', `col'] = 2*ttail(e(df_r), ///
		abs(_b[1.DD04s#`pull_het_var']/_se[1.DD04s#`pull_het_var'])) // pvalue
	
	// Number of observations
	local ++row
	matrix `var'[`row', `col'] = e(N_g) // number of households
	local ++row
	matrix `var'[`row', `col'] = e(N) // number of observations
	
	matlist `var'
	
	// Save results
	preserve
	clear
	svmat `var'
	save "$proc/encel_heterogeneity_`var'.dta", replace
	restore
}

*************
** WRAP UP **
*************
log close
exit

