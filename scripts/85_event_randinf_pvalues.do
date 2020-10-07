** EVENT STUDY OF SAVINGS VARIABLES
**  Sean Higgins

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 85_event_randinf_pvalues
cap log close
set linesize 200
log using "$logs/`project'`sample'_`time'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

************
** LOCALS **
************
// Randomization inference
if "`sample'"=="" local N_perm = 2000 
	// "I find no appreciable change in rejection rates beyond 2,000 draws"--Young (2019)
else local N_perm = 200 // laptop
if c(matsize) < `N_perm' set matsize `N_perm' 
if c(maxvar) < 32767 set maxvar 32767

#delimit ;
local randinf_vars /* not all vars because too slow */
	net_savings_ind_0_w5 
	N_withdrawals 
	sum_bc 
	sum_bc_pos_time 
	sum_bc_pos_time_wd 
	sum_bc_not_before_POS	
;
#delimit cr

**********
** DATA **
**********
foreach depvar of local randinf_vars {
	local mat_name `depvar'_ri // not doing randinf for the robustness check with `_controls'
		// because too slow
		
	use "$proc/`mat_name'_permuted_t`sample'.dta", clear
	mkmat *, matrix(results_permute)
	dim results_permute
	if "`sample'"=="" matlist results_permute // only on server
	
	use "$proc/`depvar'_teststat`sample'.dta"
	mkmat *, matrix(teststat)
	dim teststat
	if "`sample'"=="" matlist teststat

	// then put them in a matrix
	putmatrix teststat // !user! written command to send to Mata
	putmatrix results_permute
	mata: teststat_indicators = (results_permute :> teststat)
	mata: ones = J(1, `N_perm', 1)
	mata: randinf_p = ((1/`N_perm') * ones * teststat_indicators)'
		// gets mean(abs(t_p) > abs(t)); transpose to make it a column vector
	getmatrix randinf_p // !user! written back from Mata to Stata
	
	matlist randinf_p
	
	clear
	svmat randinf_p

	**********
	** SAVE **
	**********	
	// Save randomization inference p-values as data set
	save "$proc/`mat_name'_p`sample'.dta", replace
				
}

*************
** WRAP UP **
*************
log close
exit
