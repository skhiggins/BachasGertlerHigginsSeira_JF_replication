// PREPARE MERGED ENCELURB PANEL DATA FOR REGRESSIONS
**  Sean Higgins

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
local project 64_encelurb_reg_dataprep
cap log close
set linesize 200
log using "$logs/`project'_`time'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

************
** LOCALS **
************
** Control center
local randinf = 1 // to create permutations file for randomization inference
local N_perm = 2000 // number of permutations 
set seed 24637684 // random.org

**********
** DATA **
**********
use "$proc/encel_merged.dta", clear // !data!
local weeks_per_year = 52.1429 // goo.gl/3Ttao7

// Sample definition
//  1) Oportunidades beneficiaries (defined based on receiving transfers
//   in administrative data from Prospera, merged into survey)
local opben ((rec_5_09 == 1 & fechay == 2009) | (rec_6_09 == 1 & fechay == 2010))

//  2) Included in 2009 survey wave
local in_panel (y2009 == 1)

//  3) Drop obs with missing or huge outliers for a particular question 
local keep_conditions (!m_drop & !drop)
	//  (see encelurb_dataprep*.do)
	
//  4) Only localities in rollout
local rollout_locality (T04s != .)

//  5) Not missing either consumption or income (for consistent sample
//   across regressions)
local not_mi_depvars (!mi(totcons, totinc))

//  5) Exclude the late wave-1 switchers 
drop if (T04s == 1) & (bimswitch == 20095) // the late wave 1 switchers
	// (haven't had card long enough by second survey wave)
	// (explained in paper)

local sample `opben' & `in_panel' & `keep_conditions' & ///
	`rollout_locality' & `not_mi_depvars'
	// need to add the T04s!=. because in the regressions with time with card
	// rather than DD04s as the difference in difference variable, need to exclude
	// semiurban localities from the regression

describe
	
summ assetindex if `sample'
gen z_assetindex = (assetindex - r(mean))/r(sd)
summ z_assetindex if `sample'

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

foreach year in 2002 2003 2004 2009 {
		count if `opben' & y2009==1 & year==`year' & !mi(`T')
}

summ totcons if `sample'
foreach w in 1 5 { 
	winsify totcons if `sample', winsor(`w') ///
		treatment(T04s) treatment_levels(0 1) ///
		timevar(year) timevar_levels(2002 2003 2004 2009) ///
		gen(totcons_`w') highonly
	winsify totinc if `sample', winsor(`w') ///
		treatment(T04s) treatment_levels(0 1) ///
		timevar(year) timevar_levels(2002 2003 2004 2009) ///
		gen(totinc_`w') highonly
	winsify cons_durables if `sample', winsor(`w') ///
		treatment(T04s) treatment_levels(0 1) ///
		timevar(year) timevar_levels(2002 2003 2004 2009) ///
		gen(cons_durables_`w') highonly
	winsify z_assetindex if `sample', winsor(`w') ///
		treatment(T04s) treatment_levels(0 1) ///
		timevar(year) timevar_levels(2002 2003 2004 2009) ///
		gen(z_assetindex_`w')
}

foreach var of local X {
	confirm var `var'_bl
	local X_bl `X_bl' `var'_bl
}

foreach w in 1 5 {
	foreach var of local outcomes_vars_`w' {
		baselinify `var' // create `var'_bl
		local outcomes_vars_bl_`w' `outcomes_vars_bl_`w'' `var'_bl
	}
}

xtset 
sort `r(panelvar)' `r(timevar)'
foreach var of local outcomes {
	by folio_num : gen d_`var' = `var' - `var'[_n - 1] if _n != 1
}
foreach var in `outcomes_vars_1' `outcomes_vars_5' {
	by folio_num : gen d_`var' = `var' - `var'[_n - 1] if _n != 1
}

foreach w in 1 5 {
	foreach var of local outcomes_trends_`w' {
		baselinify `var' // create `var'_bl
		local outcomes_trends_bl_`w' `outcomes_trends_bl_`w'' `var'_bl
	}
}

**********
** SAVE **
**********
keep if `sample'
compress
save "$proc/encel_forreg.dta", replace

***************************************************************
** GENERATE THE PERMUTATION FILE FOR RANDOMIZATION INFERENCE **
***************************************************************
if `randinf' cluster_permute T04s ///
	using "$proc/encel_forreg_permutations.dta", ///
	cluster(localidad04) gentype(byte) n_perm(`N_perm') 
	
// Merge back into main data (to avoid having to merge in each parallelized instance)
use "$proc/encel_forreg.dta", clear
// Merge with permuted cuat_switch
merge m:1 localidad04 using "$proc/encel_forreg_permutations.dta"
assert _merge == 3
drop _merge

forval i=1/`N_perm' {
	gen byte DD04s`i' = T04s`i'*after
}
save "$proc/encel_forreg_withperm.dta", replace

*************
** WRAP UP **
*************
log close
exit
