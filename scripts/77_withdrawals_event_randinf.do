** RANDOMIZATION INFERENCE: EVENT STUDY FOR WITHDRAWALS
**  Sean Higgins

// Note: had to do this in a separate file to manually parallelize it;
//  otherwise it was too slow to do 2000 draws with full admin data

args start_perm end_perm
macro shift
macro shift // so that `*' has any additional elements
	// run the command as follows on server, to do e.g. permutations 101-200 for variable net_savings_ind_0_w5:
	//  nohup stata-mp -b do dofiles/withdrawals_eventstudy_randinf.do 101 200 N_withdrawals &
	// then the file will have local start_perm = 101 and local end_perm = 200

*****************
** DIRECTORIES **
*****************
else if "`c(username)'"=="skh2820" { // Kellogg Linux Cluster
	global main "/kellogg/proj/skh2820/ATM"
	global sample ""
}
else if strpos("`c(username)'","Sean") { // Sean's laptop
	global main "C:/Dropbox/FinancialInclusion/Bansefi/ATM"
	global sample "_sample1" // to use 1% sample on laptop
}

// To replicate on another computer simply uncomment the following lines by removing ** and change the path:
** global main "/path/to/replication/folder"

include "$main/scripts/server_header.doh"

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 77_withdrawals_event_`start_perm'_`end_perm'
cap log close
local sample $sample 
set linesize 200
log using "$logs/`project'_`time'`sample'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

************
** LOCALS **
************
// Number of permutations
local N_perm = `end_perm' - `start_perm' + 1 // end_perm and start_perm defined by args above
local include_controls_list 0 // or 0 1 for both

// Start and end of event study graph
local lowcuat -9
local hicuat   5
local cols = `hicuat' - `lowcuat' + 1 // 1 col per coefficient; 1 row per permutation

// Baseline variables that will be interacted with time FE as controls in a robustness check
#delimit ;
local stats_list 
	N_client_deposits
	N_withdrawals
	proportion_wd 
	sum_Op_deposit
	net_savings_ind_0
	years_w_account
;
#delimit cr

foreach var of local stats_list {
	local mi_stats_list `mi_stats_list' mi_`var'_bl
	local stats_list_bl `stats_list_bl' `var'_bl
}

**********
** DATA **
**********
use "$proc/account_withdrawals_forreg_withperm`sample'.dta", clear

// Create the necessary local macros
qui summ css if t==1 
local lo = r(min) 
local hi = r(max) 

summ cuat_since_switch, meanonly
local min = abs(r(min))
di r(min)
local min_1 = `min' - 1
local min_2 = `min' - 2

// Preliminaries
summ cuat_switch if t==0, meanonly
local min_control = r(min)
summ cuat_switch if t==1, meanonly
local max_treatment = r(max)
assert `max_treatment' < `min_control' // control are latest switchers

// Make empty matrices for results
foreach depvar of varlist `*' {	// `*' defined by args and macro shifts at beginning of dofile
	
	// Not the baseline variables
	if strpos("`depvar'", "_bl") continue
	
	foreach include_controls of local include_controls_list {
		// Only do the baseline controls x time FE for _w5 because it's slow
		if !strpos("`depvar'", "_w5") & `include_controls' continue
		
		if !(`include_controls') local _controls ""
		else local _controls "_blxtime"
		
		local mat_name `depvar'_ri`_controls' // _ri for randomization inference
		matrix `mat_name' = J(`N_perm', `cols', .)
	}
}

// Randomization inference
quietly { // just print a notification on each permutation's completion
	forval i = `start_perm'/`end_perm' { // end_perm and start_perm defined 
		// by args (when running do file on server)

		local j = `i' - `start_perm' + 1
		
		// Recreate cuat since switch for each permutation
		gen cuat_since_switch`i' = cuatrimester - cuat_switch`i'
		gen css`i' = cuat_since_switch`i' + `min' // dt factor var restrictions	
			// since xi cuts off the name at three characters, name it something distinct
			//  from the original css
		
		assert !missing(cuat_switch`i')
		gen t__`i' = (cuat_switch`i' < `min_control') // used t__ since xi uses 3 characters in each term of the interaction
			// for the new variable name; that way don't have to worry about `i' getting
			// differentially cut off in the name of the _I variables
		
		xi i.t__`i'*i.css`i', noomit prefix("_p")  // doing it the old way rather than using # 
		de _p* // look at new vars created by xi 
			// (note they start with _p for permutation rather than _I,
			//  so that the original _I* are kept in the data)
			
		foreach depvar of varlist `*' { // `*' defined by args and macro shifts at beginning of dofile
			
			// Not the baseline variables
			if strpos("`depvar'", "_bl") continue
			
			foreach include_controls of local include_controls_list { // with and without baseline x time controls
				// Only do the baseline controls x time FE for _w5 because it's slow
				if !strpos("`depvar'", "_w5") & `include_controls' continue
				
				if !(`include_controls') {
					local controls ""
					local _controls ""
				}
				else {
					local controls c.(`stats_list_bl')#i.cuatrimester i.(`mi_stats_list')#i.cuatrimester
					local _controls "_blxtime"
				} 
				
				local mat_name `depvar'_ri`_controls' // _ri for randomization inference

				#delimit ;
				reghdfe `depvar' i.cuatrimester `controls'
					_pt__Xcss_1_`lo'-_pt__Xcss_1_`min_2' /* pre-card permuted event dummies */
					_pt__Xcss_1_`min'-_pt__Xcss_1_`hi'   /* post-card permuted event dummies */
					, absorb(integranteid_num) vce(cluster branch_clave_loc)
				;
				#delimit cr
		
				// Put results in matrix
				local col = 0
				forval rr = `lowcuat'/`hicuat' {
					local ++col
					local _ss = `rr' + `min'
					if `_ss'==`min_1' continue // omitted period
					matrix `mat_name'[`j', `col'] = ///
						abs(_b[_pt__Xcss_1_`_ss']/_se[_pt__Xcss_1_`_ss'])
				}
			
				// Add column names
				if `i'==`start_perm' { // just need to do this once
					local _ss_low = `lowcuat' + `min'
					local _ss_hi  = `hicuat'  + `min'
					unab interactions: _pt__Xcss_1_`_ss_low'-_pt__Xcss_1_`_ss_hi' 
					matrix colnames `mat_name' = `interactions'
				}
			
				noi di "Permutation `i': `depvar'`_controls'"
			} // loop through no controls vs controls		
		} // loop through dependent variables
		
		drop cuat_switch`i' cuat_since_switch`i' t__`i' css`i' _p*
	} // loop through permutations	

} // quietly

// Save the permuted test statistics in a file to append and generate 
//  randomization inference p-values in another do file

foreach depvar of varlist `*' {	// `*' defined by args and macro shifts at beginning of dofile
	// Not the baseline variables
	if strpos("`depvar'", "_bl") continue
	
	foreach include_controls of local include_controls_list {
		// Only do the baseline controls x time FE for _w5 because it's slow
		if !strpos("`depvar'", "_w5") & `include_controls' continue
		
		if !(`include_controls') local _controls ""
		else local _controls "_blxtime"
		
		local mat_name `depvar'_ri`_controls' // _ri for randomization inference
		
		clear
		svmat `mat_name', names(col)
		save "$proc/`mat_name'_`start_perm'_`end_perm'`sample'.dta", replace
	}
}

*************
** WRAP UP **
*************
log close
exit
