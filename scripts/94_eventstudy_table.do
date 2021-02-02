** TABLE OF EVENT STUDY RESULTS

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 94_eventstudy_table
cap log close
local sample $sample 
set linesize 200
log using "$logs/`project'_`time'`sample'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

************
** LOCALS **
************
#delimit ;
local depvars /* for the main table in paper */
	N_withdrawals 
	net_savings_ind_0_w5
	sum_bc 
	sum_bc_pos_time 
	sum_bc_pos_time_wd 
	sum_bc_not_before_POS	
;
#delimit cr
local cols = wordcount("`depvars'")

// Start and end of event study graph
local lowcuat -9
local hicuat   5
local periods = `hicuat' - `lowcuat' + 1

**********
** DATA **
**********
// Main table with one column of results per graph
//  (corresponds to Figure 6a, 6b, 8a, 8b, 8c, 8d)
matrix results = J(`=`periods'*3 + 2', `=`cols' + 1', .)
matrix pvalues = J(`=`periods'*3 + 2', `=`cols' + 1', .)
	// rows are coef, se, pval; +2 for N and N_accounts
	// cols are first for period, then one for each depvar

local col = 0
foreach depvar of local depvars { 
	local ++col
	
	// Period number in first column
	if `col' == 1 {
		local row = -2 // because adding 3 below 
		forval cuat = `lowcuat'/`hicuat' {
			local row = `row' + 3
			matrix results[`row', `col'] = `cuat'
		}
		local ++col
	}
	
	// Results
	use "$proc/`depvar'`sample'.dta", clear
	mkmat *, matrix(`depvar')
	
	use "$proc/`depvar'_N`sample'.dta", clear
	mkmat *, matrix(`depvar'_N)
	
	use "$proc/`depvar'_ri_p`sample'.dta", clear
	mkmat *, matrix(`depvar'_p)
	
	local rr = 0
	local row = 0
	forval cuat = `lowcuat'/`hicuat' {
		if (!strpos("`depvar'", "sum_bc")) & (`cuat' == -1) { // omitted period
			local ++rr
			local row = `row' + 3
			continue
		}
		if (strpos("`depvar'", "sum_bc") & ((`cuat' < 0) | (`cuat' == 5))) {
				// no pre-intervention, and 5 is omitted period
			local row = `row' + 3 // will be blank in the matrix
			continue
		}
		local ++row
		local ++rr // only after the above continue because balance check matrices
			// start at cuat = 0

		matrix results[`row', `col'] = `depvar'[`rr', "b"]
		matrix pvalues[`row', `col'] = `depvar'[`rr', "p"]
		local ++row 
		matrix results[`row', `col'] = `depvar'[`rr', "se"]
		local ++row
		matrix results[`row', `col'] = `depvar'_p[`rr', 1]
	}
	
	// N
	local ++row
	matrix results[`row', `col'] = `depvar'_N[1, "N"]
	local ++row
	matrix results[`row', `col'] = `depvar'_N[1, "N_accounts"]
	
}

matlist results

// Write results to Latex
local writeto "$tables/eventstudy`sample'_`time'.tex"
local u using `writeto'

forval i = 1/`=rowsof(results)' { 
	if `i' == 1 local _append replace
	else        local _append append
	
	// Main formatting
	if mod(`i', 3) == 1 & `i' != rowsof(results) - 1 {
		local _stars stars(pvalues[`i', 1...])
		local _format format("%2.0f %3.2f %3.2f %3.2f %3.2f %3.2f %3.2f") doublenegative_cols(1)
		local _brackets ""
	}
	else if mod(`i', 3) == 2 & `i' != rowsof(results) {
		local _stars ""
		local _format format("%2.0f %3.2f %3.2f %3.2f %3.2f %3.2f %3.2f")	
		local _brackets brackets("0 () () () () () ()")
	}
	else if mod(`i', 3) == 0 {
		local _stars ""
		local _format format("%2.0f %3.2f %3.2f %3.2f %3.2f %3.2f %3.2f")
		local _brackets brackets("0 [] [] [] [] [] []") 
	}
	else if `i' >= rowsof(results) - 1 {
		local _stars ""
		local _format format("%10.0fc")
		local _brackets brackets("{}")
	}
	
	// Row titles
	if `i' == rowsof(results) - 1 local _title title("\\$ N \\$ observations") titlereplace
	else if `i' == rowsof(results) local _title title("\\$ N \\$ accounts") titlereplace
	else local _title ""
	
	// midrule
	if `i' == rowsof(results) - 2 local _midrule midrule
	else                          local _midrule ""
	
	#delimit ;
	latexify results[`i', 1...] `u', 
		`_stars'    
		`_format'   
		`_brackets' 
		`_title'   
		`_midrule'  
		`_append'
	;
	#delimit cr
}

// Appendix tables for each set of results with robustness checks
foreach depvar in N_withdrawals net_savings_ind_0 { 
	local col = 0
	
	#delimit ;
	local outcomes
		`depvar'
		`depvar'_w1
		`depvar'_w5
		`depvar'_w5_blxtime
		`depvar'_asinh
	;
	#delimit cr
	local cols = wordcount("`outcomes'")

	foreach outcome of local outcomes {
		local ++col
		use "$proc/`outcome'`sample'.dta", clear
		mkmat *, mat(`outcome')
		
		if `col'==1 {
			// First time; create matrix and initial column
			qui count
			local N_periods = r(N)
			
			matrix results = J(`=(`N_periods')*2 + 2', `=`cols' + 1', .) 
				// 2 rows per period for coef, SE
				// + 2 is for N, N_account at end
			matrix pvalues = J(`=(`N_periods')*2 + 2', `=`cols' + 1', .) 
			local row = 1
			forval i = 1/`N_periods' {
				matrix results[`row', `col'] = `outcome'[`i', "cuat_since_switch"]
				local row = `row' + 2
			}
			
			local ++col
		}

		local row = 0
		forval i = 1/`N_periods' {
			if `outcome'[`i', 1] == -1 {
				local row = `row' + 2
				continue
			}
			
			local ++row
			matrix results[`row', `col'] = `outcome'[`i', "b"]
			matrix pvalues[`row', `col'] = `outcome'[`i', "p"]
			local ++row
			matrix results[`row', `col'] = `outcome'[`i', "se"]
		}	
		// N
		use "$proc/`outcome'_N`sample'.dta", clear
		mkmat *, mat(`outcome'_N)
		local ++row 
		matrix results[`row', `col'] = `outcome'_N[1, "N"] // N
		local ++row
		matrix results[`row', `col'] = `outcome'_N[1, "N_accounts"] // N_account

	}

	matlist results

	// Export to Latex
	local writeto "$tables/`depvar'`sample'_`time'.tex"
	local u using `writeto'

	forval i = 1/`=rowsof(results)' { 
		if `i' == 1 local _append replace
		else        local _append append
		
		// Main formatting
		if mod(`i', 2) == 1 & `i' != rowsof(results) - 1 {
			local _stars stars(pvalues[`i', 1...])
			local _format format("%2.0f %3.2f %3.2f %3.2f %3.2f %3.2f") doublenegative_cols(1)
			local _brackets ""
		}
		else if mod(`i', 2) == 0 & `i' != rowsof(results) {
			local _stars ""
			local _format format("%2.0f %3.2f %3.2f %3.2f %3.2f %3.2f")	
			local _brackets brackets("0 () () () () ()")
		}
		else if `i' >= rowsof(results) - 1 {
			local _stars ""
			local _format format("%10.0fc")
			local _brackets brackets("{}")
		}
		
		// Row titles
		if `i' == rowsof(results) - 1 local _title title("\\$ N \\$ observations") titlereplace
		else if `i' == rowsof(results) local _title title("\\$ N \\$ accounts") titlereplace
		else local _title ""
		
		// midrule
		if `i' == rowsof(results) - 2 local _midrule midrule
		else                          local _midrule ""
		
		#delimit ;
		latexify results[`i', 1...] `u', 
			`_stars'    
			`_format'   
			`_brackets' 
			`_title'   
			`_midrule'  
			`_append'
		;
		#delimit cr
	}
}

// Table with one column for ATM use and one column for 
//  proportion saving
#delimit ;
local savings_since_takeup
	savings_st
	savings_w1_st
	savings_w5_st
	savings_w5_st_blxtime
	savings_asinh_st
;
#delimit cr
foreach depvar in used_ATM proportion_saving `savings_since_takeup' {
	use "$proc/`depvar'`sample'.dta", clear
	mkmat *, matrix(`depvar')

	use "$proc/`depvar'_N`sample'.dta", clear
	mkmat *, matrix(`depvar'_N)
}
matrix results = J(`=`periods'*2 + 2', 3, .)
local row = 0
local used_ATM_row = 0
local proportion_saving_row = 0
forval cuat = `lowcuat'/`hicuat' {
	local ++row
	local ++used_ATM_row
	local ++proportion_saving_row
	matrix results[`row', 1] = `cuat'
	if `cuat' >= 0 matrix results[`row', 2] = used_ATM[`used_ATM_row', "b"]
	matrix results[`row', 3] = proportion_saving[`proportion_saving_row', "b"]
	local ++row
	if `cuat' >= 0 matrix results[`row', 2] = used_ATM[`used_ATM_row', "se"]
	matrix results[`row', 3] = proportion_saving[`proportion_saving_row', "se"]
}

// Add N
local ++row
matrix results[`row', 2] = used_ATM_N[1, 1]
matrix results[`row', 3] = proportion_saving_N[1, 1]

local ++row 
matrix results[`row', 2] = used_ATM_N[1, 2]
matrix results[`row', 3] = proportion_saving_N[1, 2]

// Export to Latex
local writeto "$tables/event_means`sample'_`time'.tex"
local u using `writeto'

forval i = 1/`=rowsof(results)' { 
	if `i' == 1 local _append replace
	else        local _append append
	
	// Main formatting
	if mod(`i', 2) == 1 & `i' != rowsof(results) - 1 {
		local _format format("%2.0f %3.2f %3.2f") doublenegative_cols(1)
		local _brackets ""
	}
	else if mod(`i', 2) == 0 & `i' != rowsof(results) {
		local _format format("%2.0f %3.2f %3.2f")	
		local _brackets brackets("0 () ()")
	}
	else if `i' >= rowsof(results) - 1 {
		local _format format("%10.0fc")
		local _brackets brackets("{}")
	}
	
	// Row titles
	if `i' == rowsof(results) - 1 local _title title("\\$ N \\$ observations") titlereplace
	else if `i' == rowsof(results) local _title title("\\$ N \\$ accounts") titlereplace
	else local _title ""
	
	// midrule
	if `i' == rowsof(results) - 2 local _midrule midrule
	else                          local _midrule ""
	
	#delimit ;
	latexify results[`i', 1...] `u',  
		`_format'   
		`_brackets' 
		`_title'   
		`_midrule'  
		`_append'
	;
	#delimit cr
}

// Savings conditional on saving
local cols = wordcount("`savings_since_takeup'") + 1
matrix results = J(8, `cols', .)
matrix pvalues = J(8, `cols', .)
local col = 1

local row = 0
local rr = 0
forval cuat = 0/2 {
	local ++row 
	matrix results[`row', `col'] = `cuat'
	local ++row
}
foreach depvar of local savings_since_takeup {
	local ++col
	
	local row = 0
	local rr = 0
	forval cuat = 0/2 {
		local ++rr
		local ++row
		matrix results[`row', `col'] = `depvar'[`rr', "b"]
		matrix pvalues[`row', `col'] = `depvar'[`rr', "p"]
		local ++row
		matrix results[`row', `col'] = `depvar'[`rr', "se"]
	}
	// Add N
	local ++row
	matrix results[`row', `col'] = `depvar'_N[1, 1]
	local ++row
	matrix results[`row', `col'] = `depvar'_N[1, 2]
}

// Export to Latex
local writeto "$tables/savings_since_takeup`sample'_`time'.tex"
local u using `writeto'

forval i = 1/`=rowsof(results)' { 
	if `i' == 1 local _append replace
	else        local _append append

	// Main formatting
	if mod(`i', 2) == 1 & `i' != rowsof(results) - 1 {
		local _stars stars(pvalues[`i', 1...])
		local _format format("%2.0f %3.2f %3.2f %3.2f %3.2f %3.2f") doublenegative_cols(1)
		local _brackets ""
	}
	else if mod(`i', 2) == 0 & `i' != rowsof(results) {
		local _stars ""
		local _format format("%2.0f %3.2f %3.2f %3.2f %3.2f %3.2f")	
		local _brackets brackets("0 () () () () ()")
	}
	else if `i' >= rowsof(results) - 1 {
		local _stars ""
		local _format format("%10.0fc")
		local _brackets brackets("{}")
	}

	// Row titles
	if `i' == rowsof(results) - 1 local _title title("\\$ N \\$ observations") titlereplace
	else if `i' == rowsof(results) local _title title("\\$ N \\$ accounts") titlereplace
	else local _title ""

	// midrule
	if `i' == rowsof(results) - 2 local _midrule midrule
	else                          local _midrule ""

	#delimit ;
	latexify results[`i', 1...] `u', 
		`_stars'    
		`_format'   
		`_brackets' 
		`_title'   
		`_midrule'  
		`_append'
	;
	#delimit cr
}

*************
** WRAP UP **
*************
log close 
exit
