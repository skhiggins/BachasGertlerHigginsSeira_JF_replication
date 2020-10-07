// EFFECT OF DEBIT CARDS FROM HOUSEHOLD PANEL SURVEY
**  Sean Higgins

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 86_encelurb_regs
cap log close
set linesize 200
log using "$logs/`project'_`time'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

************
** LOCALS **
************
local wildboot = 1
local randinf  = 1
local N_perm = 2000
if c(matsize) < `N_perm' set matsize `N_perm'
if c(maxvar) < 32767 set maxvar 32767
local seed 20180912

***************
** FUNCTIONS **
***************
// Cluster wild bootstrap with Rademacher weights
cap program drop mywildboot
program define mywildboot, rclass
	#delimit ;
	syntax varlist(fv), 
		b_hat(real) 
		ddvar(varlist) 
		error_hat(varlist) 
		mu_hat(varlist) 
		cluster_tag(varlist) 
		cluster(varlist)
	;
	#delimit cr
	
	tempvar e_g r_star
	
	tokenize `varlist'
	local Y `1' 
	macro shift
	local X `*'
	
	// Rademacher weights at cluster level
	gen `e_g' = (runiform() < 0.5)*2 - 1 if `cluster_tag'==1 
		// will be -1 or 1, w/p 1/2 each
	
	// Fill in weights for rest of obs in cluster
	by `cluster': replace `e_g' = `e_g'[1] 
	assert `e_g'==-1 | `e_g'==1
 
	gen `r_star' = `mu_hat' + `e_g'*(`error_hat')
	
	xtreg `r_star' `X' `if' `in', fe vce(cluster `cluster')
	return scalar b = _b[`ddvar']
	return scalar se = _se[`ddvar']
	return scalar teststat = (_b[`ddvar'] - `b_hat')/_se[`ddvar']
end

cap program drop percentile_t 
program define percentile_t, rclass
	syntax varlist(max = 1), b_hat(real) se_hat(real) [alpha(real 0.05)]
	
	count
	local reps = r(N)
	
	local teststat `varlist'
	sort `teststat'
	
	local left_t = `teststat'[`=ceil(`=1-`alpha'/2'*`reps')']
	local right_t = `teststat'[`=floor(`=`alpha'/2'*`reps')']

	di "b_hat"
	di `b_hat'
	di "se_hat"
	di `se_hat'
	local ci_left = `b_hat' - `left_t'*`se_hat'
	di "ci_left"
	di `ci_left'
	local ci_right = `b_hat' - `right_t'*`se_hat'
	di "ci_right"
	di `ci_right'
	
	foreach r in left_t right_t ci_left ci_right {
		return scalar `r' = ``r''
	}
end

capture program drop xtreg_wildboot
program define xtreg_wildboot, rclass
	syntax varlist(fv) [if] [in] [using/], ///
		ddvar(varlist) ///
		seed(real) ///
		cluster(varlist) ///
		[reps(real 1000) alphas(string) fe]
		
	tempvar error_hat mu_hat loc_tag
	
	if "`alphas'"=="" local alphas 0.05
	if "`using'"=="" {
		tempfile wildboot_betas
		local using `wildboot_betas'
	}
		
	preserve
	
	// Run once without bootstrapping to get b_hat and errors
	xtreg `varlist' `if' `in', fe cluster(`cluster')
	predict `error_hat', e
	predict `mu_hat', xb
	local b_hat = _b[`ddvar']
	local se_hat = _se[`ddvar']
	keep if e(sample)
	sort `cluster'
	by `cluster' : gen `loc_tag' = (_n == 1) 

	simulate b=r(b) se=r(se) teststat=r(teststat), ///
		reps(`reps') seed(`seed') saving(`using', replace): ///
			mywildboot `varlist', b_hat(`b_hat') ddvar(`ddvar') ///
				error_hat(`error_hat') mu_hat(`mu_hat') ///
				cluster(`cluster') cluster_tag(`loc_tag') 
				
	foreach alpha of local alphas {
		percentile_t teststat, b_hat(`b_hat') se_hat(`se_hat') alpha(`alpha')
		return scalar ci_left_`=`alpha'*100' = r(ci_left)
		return scalar ci_right_`=`alpha'*100' = r(ci_right)		
	}
	
	restore		
end

capture program drop stacked_reg
program define stacked_reg
	#delimit ;
	syntax varlist(min=2 max=2), 
		cluster(varname)
		DD(varname) 
		T(varname) 
		ID(varname)
		[
			control(string) 
			mat(string)
			col(integer 1) /* which column of matrix to put results in */
		] 
	;
	#delimit cr
	
	if "`mat'"=="" local mat pstack
	cap confirm matrix `mat'
	if _rc {
		matrix `mat' = J(2, `col', .)
	}
	
	** transform for stacked regression
	xtset
	local rpanelvar = r(panelvar)
	local rtimevar = r(timevar)
	
	local _time i.year
	
	preserve
	tokenize `varlist'
	forval i=1/2 {
		gen _y`i' = ``i''
	}
	reshape long _y, i(folio year) j(depvar)
	
	// xtset reflecting reshape
	egen foliodepvar = group(folio_num depvar)
	xtset foliodepvar year 
	
	gen ddxdepvar1 = 0
	replace ddxdepvar1 = `dd' if depvar==1
	gen ddxdepvar2 = 0
	replace ddxdepvar2 = `dd' if depvar==2
	
	xtreg _y ddxdepvar? `_time'#i.depvar i.depvar `_time' ///
		`control' ///
	, fe vce(cluster `cluster')
	test ddxdepvar1 = ddxdepvar2
	matrix `mat'[1,`col'] = r(F)
	matrix `mat'[2,`col'] = r(p)

	restore
	qui xtset `rpanelvar' `rtimevar'
	cap drop _y* ddxdepvar*
end


**********
** DATA **
**********
use "$proc/encel_forreg_bycategory.dta", clear

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
	confirm var `var'_bl
	local X_bl `X_bl' `var'_bl
}

foreach w in 1 5 {
	foreach var of local outcomes_vars_`w' {
		local outcomes_vars_bl_`w' `outcomes_vars_bl_`w'' `var'_bl
	}
}

foreach var in `X_bl' `outcomes_vars_bl_5' `outcomes_trends_bl_5' {
	di "`var'"
	count if !mi(`var')
}

foreach w in 1 5 {
	foreach var of local outcomes_trends_`w' {
		local outcomes_trends_bl_`w' `outcomes_trends_bl_`w'' `var'_bl
	}
}

/* foreach var of varlist `X_bl'  `outcomes_vars_bl_5' `outcomes_trends_bl_5' *cons_durables?* {
	di "`var'"
	uniquevals folio if !missing(`var')
} */

// Demean controls interacted with time fixed effects
foreach var of varlist `X_bl'  `outcomes_vars_bl_5' `outcomes_trends_bl_5' {
	summ `var'
	replace `var' = `var' - r(mean)
}

*****************
** REGRESSIONS **
*****************
// Without wild bootstrapping:
foreach var in totcons totinc z_assetindex {
	// Table 4, columns 1-3:
	foreach w in "" "_1" "_5" {
		xtreg `var'`w' DD04s i.year, fe vce(cluster localidad04)
	}
	// Table 4, column 4
	xtreg `var'_5 DD04s i.year ///
		ib2002.year#c.(`X_bl'  `outcomes_vars_bl_5' `outcomes_trends_bl_5'), ///
		fe cluster(localidad04)
}

// P-value Consumption vs. Income in Table 4:
matrix pstack = J(2, 4, .)
local i = 0
foreach w in "" "_1" "_5" {
	local ++i
	stacked_reg totcons`w' totinc`w', dd(DD04s) t(T04s) /// 
		cluster(localidad04) id(folio) col(`i')
}
local ++i
stacked_reg totcons_5 totinc_5, dd(DD04s) t(T04s) /// 
	control(ib2002.year#i.depvar#c.(`X_bl' `outcomes_vars_bl_5' `outcomes_trends_bl_5')) ///
	cluster(localidad04) id(folio) col(`i')

// Debugging
di "`X_bl'  `outcomes_vars_bl_5' `outcomes_trends_bl_5'"
foreach var in `X_bl'  `outcomes_vars_bl_5' `outcomes_trends_bl_5' {
	di "`var'"
	count if !mi(`var')
}

// Put results in a matrix 
local rows = wordcount("`outcomes'")*2
matrix results = J(`rows', 4, .)
matrix pvalues = J(`rows', 4, .)
matrix parallel = J(`rows', 4, .)
matrix ri_pvalues = J(`rows', 4, .)
matrix results_N = J(`rows', 4, .) // 2 rows per reg is for N_obs N_hh
matrix boot_ci_5  = J(`rows', 8, .) // alpha = 0.05
matrix boot_ci_10 = J(`rows', 8, .) // alpha = 0.10

// Including wild bootstrap
local row = 1
foreach outcome of local outcomes {
	local col = 0
	xtreg `outcome' DD04s i.year, ///
		fe cluster(localidad04) 
	local ++col
	matrix results[`row', `col'] = _b[DD04s]
	matrix results[`=`row' + 1', `col'] = _se[DD04s]
	local teststat = abs(_b[DD04s]/_se[DD04s])
	matrix pvalues[`row', `col'] = 2*ttail(e(df_r), `teststat')
	matrix results_N[`row', `col'] = e(N)
	uniquevals folio if e(sample)
	matrix results_N[`=`row' + 1', `col'] = r(unique)
	if `wildboot' {
		xtreg_wildboot `outcome' DD04s i.year ///
			using $waste/wildboot_nowin, ///
			fe cluster(localidad04) ddvar(DD04s) ///
			alphas(0.05 0.10) seed(`seed') 
		local left_col = `col'*2 - 1
		local right_col = `left_col' + 1
		foreach a in 5 10 {
			matrix boot_ci_`a'[`row', `left_col']  = r(ci_left_`a')
			matrix boot_ci_`a'[`row', `right_col'] = r(ci_right_`a')
		}
	}
	if `randinf' {
		matrix results_permute = J(`N_perm', 1, .)
		
		_dots 0, title("Permutations") reps(`N_perm')
		forval i=1/`N_perm' {
			qui xtreg `outcome' DD04s`i' i.year, ///
				fe cluster(localidad04) 
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
		matrix ri_pvalues[`row', `col'] = r(mean) // pvalue
		restore
	}
	
	// Winsorize
	foreach w in 1 5 {
		xtreg `outcome'_`w' DD04s i.year, ///
			fe cluster(localidad04) 
		local ++col
		matrix results[`row', `col'] = _b[DD04s]
		matrix results[`=`row' + 1', `col'] = _se[DD04s]
		local teststat = abs(_b[DD04s]/_se[DD04s])
		matrix pvalues[`row', `col'] = 2*ttail(e(df_r), `teststat')
		matrix results_N[`row', `col'] = e(N)
		uniquevals folio if e(sample)
		matrix results_N[`=`row' + 1', `col'] = r(unique)
		if `wildboot' {
			xtreg_wildboot `outcome'_`w' DD04s i.year using $waste/wildboot_win`w', ///
				fe cluster(localidad04) ddvar(DD04s) ///
				alphas(0.05 0.10) seed(`seed') 
			local left_col = `col'*2 - 1
			local right_col = `left_col' + 1
			foreach a in 5 10 {
				matrix boot_ci_`a'[`row', `left_col']  = r(ci_left_`a')
				matrix boot_ci_`a'[`row', `right_col'] = r(ci_right_`a')
			}
		}
		if `randinf' {
			matrix results_permute = J(`N_perm', 1, .)
			
			_dots 0, title("Permutations") reps(`N_perm')
			forval i=1/`N_perm' {
				qui xtreg `outcome'_`w' DD04s`i' i.year, ///
					fe cluster(localidad04) 
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
			matrix ri_pvalues[`row', `col'] = r(mean) // pvalue
			restore
		}
	}
	
	// With household baseline char and pre-trends x time FE
	//  (only need to do for 5% winsorized; also checked 
	//   robustness to 1%)
	xtreg `outcome'_5 DD04s i.year ///
		ib2002.year#c.(`X_bl'  `outcomes_vars_bl_5' `outcomes_trends_bl_5'), ///
		fe cluster(localidad04)
	local ++col
	matrix results[`row', `col'] = _b[DD04s]
	matrix results[`=`row' + 1', `col'] = _se[DD04s]
	local teststat = abs(_b[DD04s]/_se[DD04s])
	matrix pvalues[`row', `col'] = 2*ttail(e(df_r), `teststat')
	matrix results_N[`row', `col'] = e(N)
	uniquevals folio if e(sample)
	matrix results_N[`=`row' + 1', `col'] = r(unique)
	if `wildboot' {
		xtreg_wildboot `outcome'_5 DD04s i.year ///
			ib2002.year#c.(`X_bl'  `outcomes_vars_bl_5' `outcomes_trends_bl_5') ///
			using $waste/wildboot_win5_FEinteract, ///
			fe cluster(localidad04) ddvar(DD04s) ///
			alphas(0.05 0.10) seed(`seed') 
		local left_col = `col'*2 - 1
		local right_col = `left_col' + 1
		foreach a in 5 10 {
			matrix boot_ci_`a'[`row', `left_col']  = r(ci_left_`a')
			matrix boot_ci_`a'[`row', `right_col'] = r(ci_right_`a')
		}
	}
	if `randinf' {
		matrix results_permute = J(`N_perm', 1, .)
		
		_dots 0, title("Permutations") reps(`N_perm')
		forval i=1/`N_perm' {
			qui xtreg `outcome'_5 DD04s`i' i.year ///
				ib2002.year#c.(`X_bl'  `outcomes_vars_bl_5' `outcomes_trends_bl_5'), ///
				fe cluster(localidad04)
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
		matrix ri_pvalues[`row', `col'] = r(mean) // pvalue
		restore
	}
	
	local row = `row' + 2
}

// Parallel trends test with hh char x FE interaction (Table 3, panel b)
local row = 0
foreach outcome of local outcomes {
	local ++row 
	local col = 1
	
	// Control mean
	reg `outcome'_5 if T04s==0 & year==2009, cluster(localidad)
	matrix parallel[`row', `col'] = _b[_cons]
	matrix parallel[`=`row'+1', `col'] = _se[_cons]
	
	xtreg `outcome' T04s##i.year i.year ///
		ib2002.year#c.(`X_bl'  `outcomes_vars_bl_5' `outcomes_trends_bl_5'), ///
		fe cluster(localidad04)
	local ++col
	matrix parallel[`row', `col'] = _b[1.T04s#2003.year]
	matrix parallel[`=`row'+1', `col'] = _se[1.T04s#2003.year]
	local ++col
	matrix parallel[`row', `col'] = _b[1.T04s#2004.year]
	matrix parallel[`=`row'+1', `col'] = _se[1.T04s#2004.year]

	local ++col
	test _b[1.T04s#2003.year] = _b[1.T04s#2004.year] = 0
	local teststat = abs(r(F))
	matrix parallel[`row', `col'] = r(p)
	
	if `randinf' {
		matrix results_permute = J(`N_perm', 1, .)
		
		_dots 0, title("Permutations") reps(`N_perm')
		forval i=1/`N_perm' {
			qui xtreg `outcome' T04s`i'##i.year i.year ///
				ib2002.year#c.(`X_bl' `outcomes_vars_bl_5' `outcomes_trends_bl_5'), ///
				fe cluster(localidad04)
			qui test _b[1.T04s`i'#2003.year] = _b[1.T04s`i'#2004.year] = 0
			matrix results_permute[`i', 1] = abs(r(F))
				
			_dots `i' 0
		}
			
		preserve
		clear
		svmat results_permute
		rename results_permute1 teststat_permute
		
		gen permuted_higher = (teststat_permute > `teststat')
		
		di "`teststat'"
		summ permuted_higher, meanonly
		matrix parallel[`=`row'+1', `col'] = r(mean) // pvalue
		restore		
	}
	
	local ++row
}

// Save these results so I can latexify them in another do file
#delimit ;
local matrices 
	results
	pvalues
	ri_pvalues
	results_N
	boot_ci_5
	boot_ci_10
	parallel
	pstack
;
#delimit cr
foreach mat of local matrices {
	di "`mat'"
	matlist `mat'
	
	if colsof(`mat') == 4 & "`mat'"!="parallel" {
		matrix colnames `mat' = "spec1" "spec2" "spec3" "spec4"
	}
	else if "`mat'"=="parallel" {
		matrix colnames `mat' = "control" "omega2003" "omega2004" "p"
	}
	else { // 8 rows (confidence intervals)
		#delimit ;
		matrix colnames `mat' = 
			"spec1_l" "spec1_r" 
			"spec2_l" "spec2_r" 
			"spec3_l" "spec3_r" 
			"spec4_l" "spec4_r" 
		;
		#delimit cr
	}

	**********
	** SAVE **
	**********
	preserve
	clear
	svmat `mat', names(col) 
	save "$proc/encel_`mat'.dta", replace
	restore
}
	
*************
** WRAP UP **
*************
cap log close
exit

