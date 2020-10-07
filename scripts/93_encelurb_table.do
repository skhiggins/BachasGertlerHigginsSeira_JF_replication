// TABLE: EFFECT OF DEBIT CARDS FROM HOUSEHOLD PANEL SURVEY
**  Sean Higgins

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 93_encelurb_table
cap log close
set linesize 200
log using "$logs/`project'_`time'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

************
** LOCALS **
************
local outcomes totcons totinc cons_durables z_assetindex
local title_totcons      "Consumption"
local title_totinc       "Income"
local title_z_assetindex "Asset index"

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

**********
** DATA **
**********
foreach mat of local matrices {
	use "$proc/encel_`mat'.dta", clear
	mkmat *, matrix(`mat')
}

// Export to Latex
local writeto "$tables/encelurb_`time'.tex"
local u using `writeto'

local writeto_parallel "$tables/encelurb_parallel_`time'.tex"
local u_parallel using `writeto_parallel'

local total_rows = wordcount("`outcomes'")*4 
local row = 1 // since +2 below
foreach outcome of local outcomes {
	if "`outcome'"=="cons_durables" {
		local row = `row' + 2
		continue // not used in final version
	}
	
	if `row' == 1 local _append "replace"
	else          local _append "append"
	
	if `row' == `total_rows' - 1 local _midrule "midrule"
	else                         local _midrule ""

	#delimit ;
	// Coefficient ;
	latexify results[`row', 1...] `u', 
		stars(pvalues[`row', 1...])
		format("%5.2f") title("`title_`outcome''")
		doublenegative
		`_append'
	;
	
	// Standard error ;
	latexify results[`=`row'+1', 1...] `u', 
		format("%5.2f") extracols(1)
		brackets("()") 
		append
	;
	
	// Confidence interval from wild bootstrap ;
	latexify boot_ci_5[`row', 1...] `u', ci(1)
		format("%5.2f") extracols(1) 
		brackets("[]") doublenegative
		append
	;
	
	// Randomization inference p-value ;
	latexify ri_pvalues[`row', 1...] `u',
		format("%3.2f") extracols(1)
		brackets("[]") 
		append
	;
	
	// Parallel trends table: coefficient;
	latexify parallel[`row', 1...] `u_parallel',
		format("%3.2f") title("`title_`outcome''")
		/* none are significant so don't worry about stars() option */
		`_append'
	;	
	
	// Parallel trends table: standard errors ;
	latexify parallel[`=`row'+1', 1...] `u_parallel',
		format("%3.2f") extracols(1)
		brackets("() () () []")
		append
	;
	
	#delimit cr
	
	local row = `row' + 2
}

// Print a midrule
tempname myf
file open `myf' `u', write append
file write `myf' "\midrule" _n
file close `myf'

#delimit ; 
// P-value consumption vs income ;
latexify pstack[2, 1...] `u', // row 2 has palues (1 has F-stat)
	format("%4.3f") title("P-value consumption vs. income")
	brackets("[]")
	append
;
// N ;
latexify results_N[1, 1...] `u',
	format("%5.0fc") title("Number of observations")
	append
;
latexify results_N[2, 1...] `u',
	format("%5.0fc") title("Number of households")
	append
;
#delimit cr

*************
** WRAP UP **
*************
log close
exit
